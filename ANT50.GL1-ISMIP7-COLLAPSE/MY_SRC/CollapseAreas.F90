!/*****************************************************************************/
! *
! *  CollapseAreas_Parallel: connected shelf regions + fracture ratio collapse
! *
! *****************************************************************************/
      SUBROUTINE CollapseAreas(Model,Solver,dt,TransientSimulation)
      USE DefUtils
      USE ConnectedAreas
      IMPLICIT NONE

      TYPE(Model_t) :: Model
      TYPE(Solver_t), TARGET :: Solver
      REAL(KIND=dp) :: dt
      LOGICAL :: TransientSimulation

      TYPE(Region_t), ALLOCATABLE :: RegionsStat(:), UniqueRegions(:)
      TYPE(Variable_t), POINTER :: RegionLabels, RegionTagVar, FractureMaskVar, CollapseMaskVar, RegionRatioVar
      TYPE(Variable_t), POINTER :: HVar
      TYPE(Variable_t), POINTER :: GroundedMaskVar, GroundedMaskElemVar
      TYPE(Mesh_t), POINTER :: Mesh
      TYPE(Element_t), POINTER :: Element
      TYPE(GaussIntegrationPoints_t) :: IP
      TYPE(Nodes_t), SAVE :: Nodes
      TYPE(ValueList_t), POINTER :: SolverParams
      TYPE(ValueList_t), POINTER :: BodyForce, Material
      REAL(KIND=dp), ALLOCATABLE :: Basis(:), dBasisdx(:,:), ddBasisddx(:,:,:)
      REAL(KIND=dp), ALLOCATABLE :: MinHLocal(:)
      LOGICAL, ALLOCATABLE :: NodeUpdated(:)
      REAL(KIND=dp), ALLOCATABLE :: RegionFractureArea(:), RegionRatio(:)
      REAL(KIND=dp), ALLOCATABLE :: RegionFractureAreaGlobal(:)
      LOGICAL, ALLOCATABLE :: RegionCollapse(:)
      REAL(KIND=dp) :: detJ, s
      REAL(KIND=dp) :: collapse_ratio, min_shelf_area
      REAL(KIND=dp) :: groundedmask_threshold
      REAL(KIND=dp) :: shelf_area, fracture_area, ratio
      REAL(KIND=dp) :: collapse_h_factor, collapse_h_minimum
      REAL(KIND=dp) :: gmask_sum
      REAL(KIND=dp) :: gmin, gmax
      REAL(Kind=dp) ::  largest,smallest
      INTEGER :: n, nTags, t, p, region, EIndex, k, nfaces, regionTag
      INTEGER :: i, node, knode, nvalid
      INTEGER :: nMaskElems, ierr
      INTEGER :: nSize
      INTEGER :: NOFActive
      LOGICAL :: Found, SAVE_REGIONS, stat, GotIt
      LOGICAL :: collapse_h_use, collapse_h_is_passive, collapse_h_is_minimum, collapse_h_is_factor
      LOGICAL :: collapse_h_minimum_found
      LOGICAL :: FractureElemental
      CHARACTER(LEN=MAX_NAME_LEN) :: SolverName = 'CollapseAreas_Parallel'
      CHARACTER(LEN=MAX_NAME_LEN) :: RegionVarName, RegionElemVarName, RegionLabelVarName, HVarname
      CHARACTER(LEN=MAX_NAME_LEN) :: FractureVarName, CollapseVarName, GroundedMaskVarName
      CHARACTER(LEN=MAX_NAME_LEN) :: FName, filename, GroundedMaskElemVarName
      CHARACTER(LEN=MAX_NAME_LEN) :: CollapseHMode
      CHARACTER(LEN=MAX_NAME_LEN),PARAMETER :: VarName="RegionLabels"
      TYPE(Variable_t),POINTER :: Var
      REAL(KIND=dp), POINTER :: Values(:)

      Mesh => Solver % Mesh
      SolverParams => GetSolverParams()
      nSize= Mesh % NumberOfBulkElements

      ! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Parameters for the collapse of connected regions based on the fracture area
      !
      ! Define a ratio for the collapse of connected regions based on the fracture area
      collapse_ratio = ListGetCReal(SolverParams,'Collapse Ratio',Found)
      IF (.NOT.Found) collapse_ratio = 0.5_dp

      ! Define a minimum shelf area threshold to consider for collapse)
      min_shelf_area = ListGetCReal(SolverParams,'Shelf Lower Limit for Collapse',Found)
      IF (.NOT.Found) min_shelf_area = 0.0_dp

      ! Gives the choice to include or exclude 0 (GL) grounded mask values on the shelf area
      groundedmask_threshold = ListGetCReal(SolverParams,'GroundedMask Threshold',Found)
      IF (.NOT.Found) groundedmask_threshold = 0._dp

      ! Some variable names
      GroundedMaskVarName = ListGetString(SolverParams,'GroundedMask Variable',Found)
      IF (.NOT.Found) GroundedMaskVarName = 'GroundedMask'
      GroundedMaskElemVarName = TRIM(GroundedMaskVarName)//'_Elem'
      RegionLabelVarName = TRIM(GroundedMaskVarName)//'_RegionLabels'

      FractureVarName = ListGetString(SolverParams,'Fracture Variable',Found)
      IF (.NOT.Found) FractureVarName = 'fracture_mask'

      CollapseVarName = ListGetString(SolverParams,'Collapse Variable',Found)
      IF (.NOT.Found) CollapseVarName = 'CollapseMask'

      HVarname = ListGetString(SolverParams,'Thickness Variable',Found)
      IF (.NOT.Found) THEN
         HVarname = 'H'
         CALL INFO(SolverName,'Thickness Variable Name not set, using '//TRIM(HVarname),level=3)
      END IF


      CollapseHMode = ListGetString(SolverParams,'Collapse Thickness Mode',Found)
      IF (.NOT.Found) CollapseHMode = 'none'

      collapse_h_factor = ListGetCReal(SolverParams,'Collapse Thickness Factor',Found)
      IF (.NOT.Found) collapse_h_factor = 0.5_dp

      collapse_h_minimum = ListGetCReal(SolverParams,'Collapse Min Thickness',Found)
      collapse_h_minimum_found = Found

      collapse_h_is_passive = (TRIM(CollapseHMode).EQ.'passive')
      collapse_h_is_minimum = (TRIM(CollapseHMode).EQ.'minimum')
      collapse_h_is_factor  = (TRIM(CollapseHMode).EQ.'factor')

      collapse_h_use = .FALSE.
      IF (TRIM(CollapseHMode).EQ.'none') THEN
         collapse_h_use = .FALSE.
      ELSE IF (collapse_h_is_passive) THEN
         collapse_h_use = .FALSE.
      ELSE IF (collapse_h_is_minimum .OR. collapse_h_is_factor) THEN
         collapse_h_use = .TRUE.
      ELSE
         CALL FATAL(SolverName,'Collapse Thickness Mode should be one of: none, passive, minimum, factor')
      END IF

      IF (collapse_h_is_factor) THEN
         IF (collapse_h_factor.LE.0._dp .OR. collapse_h_factor.GT.1._dp) THEN
            CALL FATAL(SolverName,'Collapse Thickness Factor should be in ]0,1]')
         END IF
      END IF

      n = MAX(Mesh % MaxElementNodes,Mesh % MaxElementDOFs)
      ALLOCATE(Basis(n), dBasisdx(n,3), ddBasisddx(n,3,3))
      ALLOCATE(Nodes%x(n),Nodes%y(n),Nodes%z(n))
      ALLOCATE(MinHLocal(n))


      ! Get the grounded mask variable and produce its elemental version if it is nodal
      GroundedMaskVar => VariableGet(Mesh % Variables,TRIM(GroundedMaskVarName),UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(GroundedMaskVar%Perm)) &
         CALL FATAL(SolverName,TRIM(GroundedMaskVarName)//' has no valid permutation')

      GroundedMaskElemVar => EVarGet(Solver,TRIM(GroundedMaskElemVarName),nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(GroundedMaskElemVar%Perm)) &
         CALL FATAL(SolverName,TRIM(GroundedMaskElemVarName)//' has no valid permutation')
      IF (GroundedMaskElemVar%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(GroundedMaskElemVarName)//' should be on_elements')

      IF (GroundedMaskVar%TYPE .EQ. Variable_on_elements) THEN
         
         DO t=1,nSize
            Element => Mesh % Elements(t)
            EIndex = Element % ElementIndex
            k = GroundedMaskVar % Perm(EIndex)
            IF (k.GT.0) THEN
               IF (GroundedMaskVar % Values(k) .LE. groundedmask_threshold) THEN
                  GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = -1._dp
               ELSE
                  GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = 1._dp
               END IF
            ELSE
               GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = 1._dp
            END IF
         END DO
      ELSE IF (GroundedMaskVar%TYPE .EQ. Variable_on_nodes) THEN
         DO t=1,nSize
            Element => Mesh % Elements(t)
            EIndex = Element % ElementIndex
            n = GetElementNOFNodes(Element)
            gmask_sum = 0._dp
            nvalid = 0
            DO i=1,n
               node = Element % NodeIndexes(i)
               knode = GroundedMaskVar % Perm(node)
               IF (knode.GT.0) THEN
                  gmask_sum = gmask_sum + GroundedMaskVar % Values(knode)
                  nvalid = nvalid + 1
               END IF
            END DO
            IF (nvalid.GT.0) THEN
               IF ((gmask_sum / REAL(nvalid,dp)) .LE. groundedmask_threshold) THEN
                  GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = -1._dp
               ELSE
                  GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = 1._dp
               END IF
            ELSE
               GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = 1._dp
            END IF
         END DO
      ELSE
         CALL FATAL(SolverName,TRIM(GroundedMaskVarName)//' should be on_nodes or on_elements')
      END IF

      nMaskElems = COUNT(GroundedMaskElemVar % Values .LE. -1._dp)

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Get the connected regions and their statistics
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      ! Build a dedicated label field to pass to GetConnected function 
      ! so GroundedMaskElemVar stays as a mask (-1 to 1) and is not modified
      RegionLabels => EVarGet(Solver,TRIM(RegionLabelVarName),nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(RegionLabels%Perm)) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//' has no valid permutation')
      IF (RegionLabels%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//' should be on_elements')

      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         IF (RegionLabels % Perm(EIndex) <= 0) CYCLE
         IF (GroundedMaskElemVar % Perm(EIndex) <= 0) CYCLE
         RegionLabels % Values(RegionLabels % Perm(EIndex)) = &
            GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex))
      END DO

      ! Get connected components from the dedicated label field.
      print*, TRIM(RegionLabelVarName)
      CALL GetConnected(Solver,RegionsStat,UniqueRegions,TRIM(RegionLabelVarName),CreateAux=.TRUE.)

      ! After GetConnected, this variable contains the per-element region number.
      RegionLabels => VariableGet(Mesh % Variables,TRIM(RegionLabelVarName),UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(RegionLabels%Perm)) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//' has no valid permutation')
      IF (RegionLabels%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//' should be on_elements')

      RegionTagVar => VariableGet(Mesh % Variables,TRIM(RegionLabelVarName)//'_Tag',UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(RegionTagVar%Perm)) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//'_Tag has no valid permutation')
      IF (RegionTagVar%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(RegionLabelVarName)//'_Tag should be on_elements')

      nTags = SIZE(UniqueRegions)
      WRITE(Message,'(A)') 'There is '//I2S(nTags)//' unconnected shelves'
      CALL INFO(SolverName,Message,level=3)

      IF (nTags <= 0) THEN
         CALL WARN(SolverName,'No connected shelves found')
         RETURN
      END IF

      largest=MAXVAL(UniqueRegions(:) % Area)
      smallest=MINVAL(UniqueRegions(:) % Area)
      WRITE(Message,'(A,e15.7)') 'largest shelf :',largest 
      CALL INFO(SolverName,Message,level=3)
      WRITE(Message,'(A,e15.7)') 'smallest shelf :',smallest
      CALL INFO(SolverName,Message,level=3)

      ! Definition of the Mask input
      FractureMaskVar => VariableGet(Mesh % Variables,TRIM(FractureVarName),UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(FractureMaskVar%Perm)) &
         CALL FATAL(SolverName,TRIM(FractureVarName)//' has no valid permutation')
      FractureElemental = (FractureMaskVar % TYPE .EQ. Variable_on_elements)
      IF (.NOT.FractureElemental) &
         CALL FATAL(SolverName,TRIM(FractureVarName)//' should be on_elements')
      
      print*, "Retrieved FactureMaskVar: ", TRIM(FractureVarName), ", Elemental: ", FractureElemental


      ! Collapsing Mask result
      CollapseMaskVar => EVarGet(Solver,CollapseVarName,nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(CollapseMaskVar%Perm)) &
         CALL FATAL(SolverName,TRIM(CollapseVarName)//' has no valid permutation')
      IF (CollapseMaskVar%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(CollapseVarName)//' should be on_elements')

      RegionRatioVar => EVarGet(Solver,'RegionRatio',nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(RegionRatioVar%Perm)) &
         CALL FATAL(SolverName,'RegionRatio has no valid permutation')
      IF (RegionRatioVar%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,'RegionRatio should be on_elements')

      IF (collapse_h_use) THEN
         HVar => VariableGet(Mesh % Variables, HVarname,UnfoundFatal=.TRUE.)
         IF (.NOT.ASSOCIATED(HVar%Perm)) &
            CALL FATAL(SolverName,'H has no valid permutation')
         IF (HVar%TYPE.NE.Variable_on_nodes) &
            CALL FATAL(SolverName,'H should be on_nodes')
         ALLOCATE(NodeUpdated(SIZE(HVar%Perm)))
         NodeUpdated = .FALSE.
      END IF

      ALLOCATE(RegionFractureArea(nTags),RegionRatio(nTags),RegionCollapse(nTags))
      RegionFractureArea = 0._dp
      RegionRatio = 0._dp
      RegionCollapse = .FALSE.
      CollapseMaskVar % Values = -1._dp
      RegionRatioVar % Values = -1._dp
      
      ! Compute the Fracture Area per connected shelf
      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex

         IF (ParEnv % PEs > 1) THEN
            IF (Element % PartIndex /= ParEnv % MyPE) CYCLE
         END IF

         IF (RegionTagVar % Perm(EIndex) <= 0) CYCLE
         regionTag = NINT(RegionTagVar % Values(RegionTagVar % Perm(EIndex)))
         IF (regionTag.LE.0) CYCLE
         region = 0
         DO k=1,nTags
            IF (UniqueRegions(k) % Tag == regionTag) THEN
               region = k
               EXIT
            END IF
         END DO
         IF (region.LE.0) CYCLE
             ! Region membership is already encoded by RegionLabels (region>0).
             ! Only keep elements flagged by the fracture mask for numerator area.
         IF (FractureMaskVar % Perm(EIndex) <= 0) CYCLE
             IF (FractureMaskVar % Values(FractureMaskVar % Perm(EIndex)) .GT. 0._dp) THEN
            n = GetElementNOFNodes(Element)
            Nodes % x(1:n) = Mesh % Nodes % x(Element % NodeIndexes(1:n))
            Nodes % y(1:n) = Mesh % Nodes % y(Element % NodeIndexes(1:n))
            Nodes % z(1:n) = Mesh % Nodes % z(Element % NodeIndexes(1:n))
            IP = GaussPoints(Element)
            s = 0._dp
            DO p=1,IP % n
               stat = ElementInfo(Element,Nodes,IP % U(p),IP % V(p),IP % W(p),detJ,Basis,dBasisdx,ddBasisddx,.FALSE.)
               s = s + detJ * IP % S(p)
            END DO
            RegionFractureArea(region) = RegionFractureArea(region) + s
         END IF
      END DO

      ! MPI reduction to sum the fracture areas across all partitions
      IF (ParEnv % PEs > 1) THEN
         ALLOCATE(RegionFractureAreaGlobal(nTags))
         CALL MPI_ALLREDUCE(RegionFractureArea,RegionFractureAreaGlobal,nTags, &
            MPI_DOUBLE,MPI_SUM,ELMER_COMM_WORLD,ierr)
         RegionFractureArea = RegionFractureAreaGlobal
         DEALLOCATE(RegionFractureAreaGlobal)
      END IF

      ! Collapse the connected shelves based on the fracture area ratio
      DO region=1,nTags
         shelf_area = UniqueRegions(region) % Area

         ! if shelf_area is < min_shelf_area, then the region is too small to be considered for collapse
         IF (shelf_area < min_shelf_area) CYCLE

         fracture_area = RegionFractureArea(region)
         IF (shelf_area > 0._dp) THEN
            ratio = fracture_area / shelf_area
            RegionRatio(region) = ratio
            IF (ratio > collapse_ratio) RegionCollapse(region) = .TRUE.
            
         END IF
      END DO

      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex

         IF (ParEnv % PEs > 1) THEN
            IF (Element % PartIndex /= ParEnv % MyPE) CYCLE
         END IF

         IF (RegionTagVar % Perm(EIndex) <= 0) CYCLE
         regionTag = NINT(RegionTagVar % Values(RegionTagVar % Perm(EIndex)))
         IF (regionTag.LE.0) CYCLE
         region = 0
         DO k=1,nTags
            IF (UniqueRegions(k) % Tag == regionTag) THEN
               region = k
               EXIT
            END IF
         END DO
         IF (region.LE.0) CYCLE

         IF (CollapseMaskVar % Perm(EIndex) <= 0) CYCLE
         IF (RegionRatioVar % Perm(EIndex) <= 0) CYCLE
         IF (RegionCollapse(region)) THEN
            CollapseMaskVar % Values(CollapseMaskVar % Perm(EIndex)) = 1._dp

            IF (collapse_h_use) THEN
               n = GetElementNOFNodes(Element)

               IF (collapse_h_is_minimum) THEN
                  IF (collapse_h_minimum_found) THEN
                     MinHLocal(1:n) = collapse_h_minimum
                  ELSE
                     BodyForce => GetBodyForce(Element)
                     Material => GetMaterial(Element)
                     MinHLocal(1:n) = ListGetConstReal(BodyForce,'H Lower Limit',GotIt)
                     IF (.NOT.GotIt) MinHLocal(1:n) = ListGetConstReal(Material,'Min H',GotIt)
                     IF (.NOT.GotIt) CALL FATAL(SolverName, &
                        & 'Collapse Mode=minimum requires Collapse Min Thickness or local H lower limit')
                  END IF
               ELSE IF (collapse_h_is_factor) THEN
                  BodyForce => GetBodyForce(Element)
                  Material => GetMaterial(Element)
                  MinHLocal(1:n) = ListGetConstReal(BodyForce,'H Lower Limit',GotIt)
                  IF (.NOT.GotIt) MinHLocal(1:n) = ListGetConstReal(Material,'Min H',GotIt)
                  IF (.NOT.GotIt) MinHLocal(1:n) = 1.0_dp
               END IF

               DO i=1,n
                  node = Element % NodeIndexes(i)
                  IF (node.LE.0) CYCLE
                  IF (node.GT.SIZE(HVar%Perm)) CYCLE

                  knode = HVar % Perm(node)
                  IF (knode.LE.0) CYCLE
                  IF (knode.GT.SIZE(NodeUpdated)) CYCLE
                  IF (NodeUpdated(knode)) CYCLE

                  IF (collapse_h_is_minimum) THEN
                     HVar % Values(knode) = MinHLocal(i)
                  ELSE IF (collapse_h_is_factor) THEN
                     HVar % Values(knode) = collapse_h_factor * HVar % Values(knode)
                     ! Enforce the configured minimum thickness (Min H / H Lower Limit)
                     IF (HVar % Values(knode) < MinHLocal(i)) THEN
                        HVar % Values(knode) = MinHLocal(i)
                     END IF
                  END IF

                  NodeUpdated(knode) = .TRUE.
               END DO
            END IF
         ELSE
            CollapseMaskVar % Values(CollapseMaskVar % Perm(EIndex)) = 0._dp
         END IF
         RegionRatioVar % Values(RegionRatioVar % Perm(EIndex)) = RegionRatio(region)
      END DO

      SAVE_REGIONS = ListGetLogical(SolverParams,'Save regions labels',Found)
      IF (.NOT.Found) SAVE_REGIONS = .FALSE.
      IF (SAVE_REGIONS) THEN
         FName = ListGetString(SolverParams,'File Name',Found)
         IF (.NOT.Found) FName = 'output_collapse.txt'
         filename = TRIM(FName)
         OPEN(12,file=TRIM(filename))
         DO region=1,nTags
            shelf_area = UniqueRegions(region) % Area
            fracture_area = RegionFractureArea(region)
            ratio = 0._dp
            IF (shelf_area > 0._dp) ratio = fracture_area / shelf_area
         END DO
         CLOSE(12)
      END IF

      DEALLOCATE(RegionFractureArea,RegionRatio,RegionCollapse)
      DEALLOCATE(Basis,dBasisdx,ddBasisddx)
      DEALLOCATE(Nodes%x,Nodes%y,Nodes%z)
      DEALLOCATE(MinHLocal)
      IF (collapse_h_use) DEALLOCATE(NodeUpdated)

      END SUBROUTINE CollapseAreas
