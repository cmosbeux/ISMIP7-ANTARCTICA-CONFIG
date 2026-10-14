!/*****************************************************************************/
! *
! *  Elmer/Ice, a glaciological add-on to Elmer
! *  http://elmerice.elmerfem.org
! *
! *
! *  This program is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU General Public License
! *  as published by the Free Software Foundation; either version 2
! *  of the License, or (at your option) any later version.
! *
! *  This program is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! *  GNU General Public License for more details.
! *
! *  You should have received a copy of the GNU General Public License
! *  along with this program (in file fem/GPL-2); if not, write to the
! *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
! *  Boston, MA 02110-1301, USA.
! *
! *****************************************************************************/
! ******************************************************************************
! *
! *  Author: F. Gillet-Chaulet (IGE)
! *  Email:  fabien.gillet-chaulet@univ-grenoble-alpes.fr
! *  Web:    http://elmerice.elmerfem.org
! *
! *  Original Date: 28/09/2023
! * 
! * TO DO:
! *****************************************************************************
MODULE ConnectedAreas
    USE DefUtils
    implicit none

    LOGICAL :: DEBUG=.FALSE.
    LOGICAL :: SerialLabelOutPut=.FALSE.

    TYPE Queue_t
         INTEGER :: maxsize
         INTEGER :: top
         INTEGER,ALLOCATABLE :: items(:)
    END TYPE Queue_t

    TYPE Region_t
       INTEGER :: Tag
       INTEGER :: NoE
       REAL(KIND=dp) :: Area
    END TYPE Region_t

    TYPE HaloShare_t
       INTEGER :: count
       INTEGER, ALLOCATABLE :: GEleIDX(:),EleIDX(:)
   END TYPE HaloShare_t
   
CONTAINS

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! MAIN SUBROUTINE - GET REGIONS OF ELEMENTS CONNECTED BY AN EDGE (FACE) 
!  INPUT :: 
!     Solver  : Current Solver
!  OUTPUT :: 
!     Regions
!     UniqueRegions
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   SUBROUTINE GetConnected(Solver,RegionsStat,UniqueRegions,Varname,CreateAux)
    TYPE(Solver_t), TARGET :: Solver
    TYPE(Region_t), ALLOCATABLE,INTENT(OUT) :: RegionsStat(:),UniqueRegions(:)
    CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: Varname
    LOGICAL,OPTIONAL :: CreateAux

    TYPE(Variable_t),POINTER :: Var
    REAL(KIND=dp), POINTER :: Values(:)
    REAL(KIND=dp), ALLOCATABLE :: MaskValues(:)
    INTEGER, POINTER :: Perm(:)

    TYPE(Mesh_t), POINTER :: Mesh
    TYPE(Element_t),POINTER :: Element,Parent
    TYPE(Element_t),POINTER :: Faces(:),Face
    TYPE(Queue_t) :: Queue
    TYPE(GaussIntegrationPoints_t) :: IP
    TYPE(Nodes_t),SAVE :: Nodes

    REAL(KIND=dp), ALLOCATABLE :: Basis(:), dBasisdx(:,:), &
                                      ddBasisddx(:,:,:)
    REAL(KIND=dp) :: detJ,s

    INTEGER :: t,i,p
 
    INTEGER :: nSize,n
    INTEGER :: label,region
    INTEGER :: EIndex,GElementIndex,pidx
    INTEGER :: nfaces
    LOGICAL :: stat, Found
    LOGICAL :: Parallel
    REAL(KIND=dp) :: mask_threshold
    TYPE(ValueList_t), POINTER :: SolverParams
   

    CHARACTER(LEN=MAX_NAME_LEN) :: LabelName="RegionLabel"
    CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='GetConnectedAreas'

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    IF (PRESENT(Varname)) THEN
        LabelName=TRIM(Varname)
    END IF

    ! IF (ParEnv % MyPE .EQ. 0) THEN
    !   WRITE(*,'(A)') 'LABEL=['//TRIM(LabelName)//']'
    ! END IF

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! Do some initialisation
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Mesh => Solver % Mesh
    SolverParams => GetSolverParams(Solver)
    mask_threshold = ListGetCReal(SolverParams,'Region Mask Threshold',Found)
    IF (.NOT.Found) mask_threshold = -0.5_dp

    !! to see if we work on a BC
    nSize = Mesh % NumberOfBulkElements

    Parallel = ( ParEnv % PEs > 1 )

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !! reminder if created in sif with "-elem" var get permutation from Active elements; 
    !! so no halo which are mandatory if we want to detect Active/Passive boundaries
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Var =>  EVarGet(Solver,LabelName,nSize,SerialLabelOutPut)
    Values => Var % Values
    Perm => Var % Perm

    IF (.NOT.ASSOCIATED(Perm)) &
        CALL FATAL(SolverName,"Permutation not associated for variable "//TRIM(LabelName))

    n = MAX(Mesh % MaxElementNodes,Mesh % MaxElementDOFs)
    ALLOCATE( Basis(n), dBasisdx(n,3), ddBasisddx(n,3,3))
    ALLOCATE(Nodes%x(n),Nodes%y(n),Nodes%z(n))

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! Get mesh edges or faces
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    
    CALL FindMeshEdges(Mesh,.FALSE.)
    SELECT CASE(Mesh % MeshDim)
       CASE(2)
        Faces => Mesh % Edges
       CASE(3)
        Faces => Mesh % Faces
    END SELECT

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! Initialise Queue
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    CALL QueueInit(Queue,nSize)

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! Fill Region label
    ! Use the original variable values as a region mask:
    ! value > threshold means excluded from connectivity,
    ! value <= threshold means included.
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ALLOCATE(MaskValues(SIZE(Values)))
    MaskValues = Values
    Values = -1
    label = 0

    DO t=1,nSize
        Element => Mesh % Elements(t)
        EIndex = Element % ElementIndex 
        
        IF (Perm(EIndex).LT.0) &
          CALL FATAL(SolverName,"Permutation error")

        IF (MaskValues(Perm(EIndex)).GT.mask_threshold) CYCLE
        IF (Values(Perm(EIndex)).GT.0) CYCLE

        label = label + 1
        Values(Perm(EIndex)) = label


        CALL QueuePush(Queue,EIndex)

        DO WHILE (Queue%top.GT.0)
           CALL QueuePop(Queue,EIndex)
           Element => Mesh % Elements(EIndex)

           SELECT CASE(Mesh % MeshDim)
            CASE(2)
             nfaces=Element % TYPE % NumberOfEdges
            CASE(3)
             nfaces=Element % TYPE % NumberOfFaces
           END SELECT

           DO i=1,nfaces
             SELECT CASE(Mesh % MeshDim)
              CASE(2)
               Face =>  Mesh % Edges (Element % EdgeIndexes(i))
              CASE(3)
               Face =>  Mesh % Faces (Element % FaceIndexes(i))
             END SELECT

             IF (.NOT.ASSOCIATED(Face)) &
               CALL FATAL(SolverName,'Face not found')

             Parent => Face % BoundaryInfo % Left
             IF (ASSOCIATED(Parent)) THEN 
               pidx = Perm(Parent%ElementIndex)
               IF (pidx.LE.0) CYCLE
                IF ((MaskValues(pidx).LE.mask_threshold)&
                  .AND.(Values(pidx).LE.0)) THEN
                Values(pidx)=label      
                  CALL QueuePush(Queue,Parent%ElementIndex)
                END IF
             END IF
             Parent => Face % BoundaryInfo % Right
             IF (ASSOCIATED(Parent)) THEN 
               pidx = Perm(Parent%ElementIndex)
               IF (pidx.LE.0) CYCLE
                IF ((MaskValues(pidx).LE.mask_threshold)&
                  .AND.(Values(pidx).LE.0)) THEN
                Values(pidx)=label      
                  CALL QueuePush(Queue,Parent%ElementIndex)
                END IF
             END IF

            END DO           
           
        END DO

    END DO

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! Compute region statistiques
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    CALL InitRegion(RegionsStat,label)

    DO t=1,nSize
        Element => Mesh % Elements(t)
        EIndex= Element % ElementIndex 

         region=Values(Perm(EIndex))
         IF (region.LE.0) CYCLE

         GElementIndex = Element % GElementIndex
         IF (GElementIndex.LT.RegionsStat(region) % Tag) &
            RegionsStat(region) % Tag = GElementIndex

        IF (Parallel) THEN
           IF ( Element % PartIndex /= ParEnv % MyPE) CYCLE 
        END IF

         RegionsStat(region) % NoE =   RegionsStat(region) % NoE + 1

         n  = GetElementNOFNodes(Element)

         Nodes % x(1:n) = Mesh % Nodes % x(Element % NodeIndexes(1:n))
         Nodes % y(1:n) = Mesh % Nodes % y(Element % NodeIndexes(1:n))
         Nodes % z(1:n) = Mesh % Nodes % z(Element % NodeIndexes(1:n))
         IP = GaussPoints( Element )
         DO p = 1, IP % n
           stat = ElementInfo( Element, Nodes, IP % U(p), IP % V(p), &
             IP % W(p), detJ, Basis, dBasisdx, ddBasisddx, .FALSE.) 
           s = detJ * IP % S(p)                           

            RegionsStat(region) % Area = RegionsStat(region) % Area  + s
         END DO
    END DO


    CALL GetUniqueRegions(Solver,LabelName,RegionsStat,UniqueRegions)

    IF (PRESENT(CreateAux)) THEN
      IF (CreateAux) THEN
        CALL CreateRegionVariables(Solver,LabelName,RegionsStat)
      ENDIF
    ENDIF

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !  cleaning
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    DEALLOCATE(Queue%items)
    DEALLOCATE(Basis,dBasisdx,ddBasisddx)
    DEALLOCATE(Nodes%x,Nodes%y,Nodes%z)
    DEALLOCATE(MaskValues)
    
   END SUBROUTINE GetConnected

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   SUBROUTINE CreateRegionVariables(Solver,LabelName,Regions)
      TYPE(Solver_t), TARGET :: Solver
      CHARACTER(LEN=MAX_NAME_LEN),INTENT(IN) :: LabelName
      TYPE(Region_t), ALLOCATABLE,INTENT(IN) :: Regions(:)

      TYPE(Mesh_t), POINTER :: Mesh
      TYPE(Variable_t), POINTER :: RegionLabels
      TYPE(Variable_t), POINTER :: Tag,Area,NoE
      TYPE(Element_t),POINTER :: Element
      INTEGER ::  t
      INTEGER :: region
      INTEGER :: nSize
      INTEGER :: EIndex
      CHARACTER(LEN=MAX_NAME_LEN) :: VarName
      CHARACTER(LEN=MAX_NAME_LEN) :: SolverName="CreateRegionVariables"

      Mesh => Solver % Mesh

      nSize =  Mesh % NumberOfBulkElements

      RegionLabels =>  VariableGet( Mesh % Variables,TRIM(LabelName),UnfoundFatal=.True.)
      IF (.NOT.ASSOCIATED(RegionLabels%Perm)) &
        CALL FATAL(SolverName,"RegionLabels has no valid permutation")
      IF (RegionLabels%TYPE.NE.Variable_on_elements) &
        CALL FATAL(SolverName,"RegionLabels should be on_elements")

      VarName = TRIM(LabelName)//"_Tag"
      Tag => EVarGet(Solver,VarName,nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(Tag%Perm)) &
        CALL FATAL(SolverName,"RegionNumber has no valid permutation")
      IF (Tag%TYPE.NE.Variable_on_elements) &
        CALL FATAL(SolverName,"RegionNumber should be on_elements")

      VarName = TRIM(LabelName)//"_Area"
      Area => EVarGet(Solver,VarName,nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(Area%Perm)) &
        CALL FATAL(SolverName,"RegionArea has no valid permutation")
      IF (Area%TYPE.NE.Variable_on_elements) &
        CALL FATAL(SolverName,"RegionArea should be on_elements")

      VarName = TRIM(LabelName)//"_NoE"
      NoE => EVarGet(Solver,VarName,nSize,.TRUE.)
      IF (.NOT.ASSOCIATED(NoE%Perm)) &
        CALL FATAL(SolverName,"RegionNoE has no valid permutation")
      IF (NoE%TYPE.NE.Variable_on_elements) &
        CALL FATAL(SolverName,"RegionNoE should be on_elements")

      Tag % Values = -1
      Area % Values = -1
      NoE % Values = -1

      DO t=1,nSize
        Element => Mesh % Elements(t)
        EIndex= Element % ElementIndex 

         region= RegionLabels % Values( RegionLabels % Perm(EIndex))

         IF (region.GT.0) THEN
           Tag % Values(Tag % Perm(EIndex))=Regions(region) % Tag
           Area % Values(Area % Perm(EIndex))=Regions(region) % Area
           NoE % Values(NoE%Perm(EIndex))= Regions(region) % NoE
         END IF
      END DO

   END SUBROUTINE CreateRegionVariables

   FUNCTION EVarGet(Solver,VarName,nSize,Output) RESULT(Var)
      TYPE(Solver_t), TARGET :: Solver
      CHARACTER(LEN=*),INTENT(IN) :: Varname
      INTEGER :: nsize
      LOGICAL :: Output
      TYPE(Variable_t), POINTER :: Var

      REAL(KIND=dp), POINTER :: Solution(:)
      INTEGER, POINTER :: TmpPerm(:)
      INTEGER :: i 


      Var => VariableGet( Solver % Mesh % Variables,TRIM(VarName),ThisOnly=.TRUE.)
      IF (.NOT.ASSOCIATED(Var)) THEN
          ALLOCATE(Solution(nSize),TmpPerm(nSize))
          Solution = 0.0d0
          DO i=1,nSize
              TmpPerm(i) = i
          END DO
          CALL VariableAdd( Solver % Mesh % Variables, Solver % Mesh, Solver,&
             TRIM(VarName), 1, Solution, TmpPerm, &
             Output=Output, TYPE=Variable_on_elements )

          Var => VariableGet( Solver % Mesh % Variables,TRIM(VarName),ThisOnly=.TRUE.)
      END IF

      IF (size(Var%Values).NE.nSize)  &
         CALL FATAL("EVarGet","Size error with variable "//TRIM(VarName))
   END FUNCTION EVarGet

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! GET Unique regions
!  INPUT :: 
!     Solver  : Current Solver
!     VarName
!  OUTPUT :: 
!     Regions
!     UniqueRegions
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   SUBROUTINE GetUniqueRegions(Solver,VarName,Regions,UniqueRegions)
         TYPE(Solver_t), TARGET :: Solver
         CHARACTER(LEN=MAX_NAME_LEN),INTENT(IN) :: Varname
         TYPE(Region_t), ALLOCATABLE,INTENT(INOUT) :: Regions(:)
         TYPE(Region_t), ALLOCATABLE,INTENT(OUT) ::UniqueRegions(:)
         
         TYPE(HaloShare_t), ALLOCATABLE, SAVE :: Halo(:)
         TYPE(Variable_t), POINTER :: RegionLabels 
         TYPE(Mesh_t), POINTER :: Mesh

         CHARACTER(LEN=MAX_NAME_LEN) :: SolverName="GetUniqueRegions"

         TYPE Send_t
           INTEGER, ALLOCATABLE :: val(:)
         END TYPE Send_t
         TYPE(Send_t),ALLOCATABLE :: Send(:),Recv(:)

         INTEGER, Allocatable :: AllRegions(:),buff(:),TotalRegions(:),disps(:),UniqueTags(:)
         INTEGER, ALLOCATABLE :: TotalNoE(:),AllNoE(:)
         INTEGER, ALLOCATABLE :: status(:)
         INTEGER :: i,j,k
         INTEGER :: ierr
         INTEGER :: EIndex
         INTEGER :: region,nregions,nTags,nTot

         REAL(KIND=dp),ALLOCATABLE :: TotalArea(:),AllArea(:)

         LOGICAL :: Converged, AllConverged
         LOGICAL :: Parallel

         Parallel = ( ParEnv % PEs > 1 )

         nregions= size(Regions)

         Mesh => Solver % Mesh
         RegionLabels =>  VariableGet( Mesh % Variables,TRIM(VarName),UnfoundFatal=.True.)
         IF (.NOT.ASSOCIATED(RegionLabels%Perm)) &
           CALL FATAL(SolverName,"RegionLabels has no valid permutation")
         IF (RegionLabels%TYPE.NE.Variable_on_elements) &
           CALL FATAL(SolverName,"RegionLabels should be on_elements")

         ! Parallel REDUCTION
         IF (Parallel) THEN
             
            IF (.NOT.ALLOCATED(Halo)) &
                 CALL DetectHalo(Solver,Halo)

              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              ! Tmp ALLOCATION
              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              ALLOCATE(status(ParEnv % PEs), &
                       Recv(ParEnv % PEs), &
                       Send(ParEnv % PEs), &
                       TotalRegions(ParEnv % PEs), &
                       disps(ParEnv % PEs), &
                       buff(nregions))

              DO i=1,ParEnv % PEs
                 k = Halo(i) % count
                 ALLOCATE(Recv(i) % val(k),Send(i) % val(k))
              END DO

              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              ! exchange tags between halo elements
              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              DO WHILE(.TRUE.)

                 DO i=1,ParEnv % PEs

                    k = Halo(i) % count

                    Send(i) % val = -1

                    DO j=1,k
                       EIndex = Halo(i) % EleIDX(j)
                       region= RegionLabels % Values( RegionLabels % Perm(EIndex))
                       IF (region.GT.0) &
                          Send(i) % val(j) = Regions(region) % Tag
                    END DO

                    CALL MPI_IRECV(Recv(i) % val , k, MPI_INTEGER, i-1, 195, ELMER_COMM_WORLD, &
                       status(i), ierr)
                    CALL MPI_SEND(Send(i) % val , k, MPI_INTEGER, i-1, 195, ELMER_COMM_WORLD, ierr)
                 END DO

                 CALL MPI_Waitall(ParEnv % PEs, status(1:ParEnv % PES), MPI_STATUSES_IGNORE, ierr)
                 status = MPI_REQUEST_NULL

                 Converged = .TRUE.
                  DO i=1,ParEnv % PEs
                    k = Halo(i) % count
                    DO j=1,k
                       EIndex = Halo(i) % EleIDX(j)
                       region= RegionLabels % Values( RegionLabels % Perm(EIndex))
                       IF (region.GT.0) THEN
                          IF (Recv(i) % val(j).LT.1) CYCLE
                          IF (Recv(i) % val(j).LT.Regions(region) % Tag) THEN
                               Regions(region) % Tag = Recv(i) % val(j)
                               Converged = .FALSE.
                          END IF
                       END IF
                    END DO
                  END DO

                  CALL MPI_ALLREDUCE(Converged, AllConverged , 1, MPI_LOGICAL,MPI_LAND, ELMER_COMM_WORLD, ierr )

                  IF (AllConverged) THEN
                    EXIT
                 END IF
              END DO

            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ! Gateher unique region tags.....
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            CALL MPI_ALLGATHER(nregions, 1 , MPI_INTEGER, &
                TotalRegions,1, MPI_INTEGER, ELMER_COMM_WORLD, ierr)

            nTot=SUM(TotalRegions)
            ALLOCATE(AllRegions(nTot))

            disps(1) = 0
            DO i=2,ParEnv % PEs
               disps(i) = disps(i-1) + TotalRegions(i-1)
            END DO

            buff(:)=Regions(:) % Tag
            CALL MPI_ALLGATHERv(buff, nregions , MPI_INTEGER, &
                AllRegions,TotalRegions, disps, MPI_INTEGER, ELMER_COMM_WORLD, ierr)
     
            CALL unique_sort(SUM(TotalRegions),AllRegions,UniqueTags)
            nTags = size(UniqueTags)

            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ! Compute region statistics
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ALLOCATE(TotalArea(nTags),TotalNoE(nTags),AllArea(nTags),AllNoE(nTags))

            TotalArea=0._dp
            TotalNoE=0
            DO i=1,nTags
              DO j=1,nregions
                 IF (Regions(j) % Tag /= UniqueTags(i)) CYCLE
                 TotalArea(i) = TotalArea(i) + Regions(j) % Area
                 TotalNoE(i) = TotalNoE(i) + Regions(j) % NoE
              END DO
            END DO

            CALL MPI_ALLREDUCE(TotalArea,AllArea,nTags,MPI_DOUBLE,MPI_SUM,ELMER_COMM_WORLD, ierr )
            CALL MPI_ALLREDUCE(TotalNoE,AllNoE,nTags,MPI_INTEGER,MPI_SUM,ELMER_COMM_WORLD, ierr )

            DO i=1,nTags
              DO j=1,nregions
                IF (Regions(j) % Tag /= UniqueTags(i)) CYCLE
                  Regions(j) % Area = AllArea(i)
                  Regions(j) % NoE = AllNoE(i)
              END DO
            END DO

            CALL InitRegion(UniqueRegions,nTags)
            UniqueRegions(1:nTags) % Tag = UniqueTags(1:nTags)
            UniqueRegions(1:nTags) % Area = AllArea(1:nTags)
            UniqueRegions(1:nTags) % NoE = AllNoE(1:nTags)

            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ! Cleaning
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            DEALLOCATE(status,Recv,Send,TotalRegions,disps,buff)
            DEALLOCATE(UniqueTags)
            DEALLOCATE(TotalArea,TotalNoE,AllArea,AllNoE)
            DEALLOCATE(AllRegions)

            CALL MPI_BARRIER(ELMER_COMM_WORLD,ierr)

        ELSE
           !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
           ! serial case
           !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
           CALL InitRegion(UniqueRegions,nregions)
            UniqueRegions=Regions
        END IF

      END SUBROUTINE GetUniqueRegions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! DETECT HALO ELEMENTS TO SHARE REGIONS TAGS
!  INPUT :: Solver
!  OUTPUT :: halo(ParEnv % PEs):: elements indices for halo-elements shared with each partition
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      SUBROUTINE DetectHalo(Solver,Halo)
         TYPE(Solver_t),TARGET :: Solver
         TYPE(HaloShare_t), ALLOCATABLE, INTENT(OUT) :: Halo(:)
         
         CHARACTER(len=MAX_NAME_LEN) :: SolverName="DetectHalo"
         TYPE flist_t
          INTEGER, POINTER :: Pes(:)
         END TYPE flist_t

         TYPE(Mesh_t), POINTER :: Mesh 
         TYPE(Element_t), POINTER :: Element
         TYPE(NeighbourList_t), ALLOCATABLE :: MeshHalo(:)
         TYPE(HaloShare_t), ALLOCATABLE :: RecvHalo(:)
         TYPE(flist_t) :: list(8)

         INTEGER, ALLOCATABLE :: HaloIndexes(:)
         INTEGER, ALLOCATABLE :: status(:)
         INTEGER, ALLOCATABLE :: tmp(:),tmp2(:)

         INTEGER :: nelem,nd
         INTEGER :: t,j,l,p,q,k,i,n,Sweep
         INTEGER :: HaloCount
         INTEGER :: ierr
         INTEGER :: cpt
      
         LOGICAL, POINTER :: ig(:)
         LOGICAL, ALLOCATABLE :: keep(:)
         LOGICAL :: Intf
 
         CALL INFO(SolverName,"DETECT HALO ELEMENTS - IN",level=5)
      
         Mesh => GetMesh(Solver)
      
         ig => Mesh % ParallelInfo % GInterface
      
         nelem = Mesh % NumberOfBulkElements

         ALLOCATE(Halo(ParEnv % PEs))
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         ! do some temporary allocation
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         ALLOCATE(MeshHalo(nelem) )
         DO t=1,nelem
              NULLIFY( MeshHalo(t) % Neighbours )
         END DO     
         ALLOCATE(RecvHalo(ParEnv % PEs))
         ALLOCATE(HaloIndexes(nelem))
         ALLOCATE(status(ParEnv % PEs))
      
         ! Loop over Bulk elments:
         !-----------------
         HaloCount = 0
         DO t=1,nelem
            Element => Mesh % Elements(t)
      
            nd = Element % Type % ElementCode/100
      
            ! Check that this is an halo
            Intf = ALL(ig(Element % NodeIndexes(1:nd)))
      
            IF ( Intf ) THEN
      
               MeshHalo(t) % Neighbours => NULL()
               DO j=1,nd
                  l = Element % NodeIndexes(j)
                  list(j) % pes => Mesh % ParallelInfo % NeighbourList(l) % Neighbours
              END DO
              !
              ! Determine the intersection of the PE-lists:
              ! We should find as many shared hits as there are nodes in the face.
              !-------------------------------------------------------------------
              DO p = 1,SIZE(list(1) % pes)
                j = 1
                DO k = 2,nd
                  DO q=1,SIZE(list(k) % pes)
                    IF( list(1)% pes(p)==list(k) % pes(q) ) THEN
                      j=j+1;
                      EXIT
                    END IF
                  END DO
                END DO
                IF (j==nd) CALL AddToCommonList(MeshHalo(t) % Neighbours, list(1) % Pes(p))
              END DO
      
              IF (ASSOCIATED(MeshHalo(t) % Neighbours)) THEN
                IF (size(MeshHalo(t) % Neighbours).LT.2) THEN
                 DEALLOCATE(MeshHalo(t) % Neighbours); MeshHalo(t) % Neighbours => NULL()
                 CYCLE
                END IF
              ENDIF
      
              HaloCount = HaloCount + 1
              HaloIndexes(HaloCount) = Element % ElementIndex
      
             END IF
      
         END DO
      
         IF (HaloCount.EQ.0) CALL FATAL(SolverName,"there is no halo?")
      
         DO Sweep=1,2
      
           Halo % count = 0
      
           DO t=1,HaloCount
             k = HaloIndexes(t)
      
             Element => Mesh % Elements(k)
      
             IF (.NOT.ASSOCIATED(MeshHalo(k) % Neighbours)) &
                    CALL FATAL(SolverName,"error we have no neighbours")
      
             DO j=1,SIZE(MeshHalo(k) % Neighbours)
               l = MeshHalo(k)  % Neighbours(j) + 1
               IF(l==(ParEnv % MyPE+1)) CYCLE
               Halo(l) % count = Halo(l)  % count + 1
               n = Halo(l) % count
               !Actually write the data
               IF(Sweep == 2) THEN
                 Halo(l) % GEleIDX(n) = Element % GElementIndex
                 Halo(l) % EleIDX(n) = Element % ElementIndex
               END IF
               END DO
      
              IF (Sweep ==2) THEN
                    DEALLOCATE(MeshHalo(k) % Neighbours)
                    MeshHalo(k) % Neighbours => NULL()
              END IF
      
            END DO
      
            DO i=1,ParEnv % PEs
               n = Halo(i) % count
      
              IF(Sweep==1) THEN
               ALLOCATE(Halo(i) % GEleIDX(n),Halo(i) % EleIDX(n))
              ELSE
                IF (n.GT.1) CALL SortI(Halo(i) % count , Halo(i) % GEleIDX,Halo(i) % EleIDX)
              END IF
      
            END DO
      
         END DO
      
         !! AT THIS POINT For partition k, 
         !!   Halo(i) in partition "k" should contain the number of potential Halo shared with partition i
         !!   Halo(k) in partition "i" should contain the number of potential Halo shared with partition k
         !!     it may appen that all nodes where shared but not the element itself, so we should take the intersection
         !! SHARE NUMBER OF POTENTIAL HALOs
         DO i=1,ParEnv % PEs
           CALL MPI_IRECV(RecvHalo(i) % count, 1, MPI_INTEGER, i-1, 194, ELMER_COMM_WORLD, &
              status(i), ierr)
           CALL MPI_SEND(Halo(i) % count,  1, MPI_INTEGER, i-1, 194, ELMER_COMM_WORLD, ierr)
         END DO
         CALL MPI_Waitall(ParEnv % PEs, status(1:ParEnv % PES), MPI_STATUSES_IGNORE, ierr)
         status = MPI_REQUEST_NULL
      
         !! SEND Global element indices
         DO i=1,ParEnv % PEs
           n = RecvHalo(i) % count
           k = Halo(i) % count
      
           ALLOCATE(RecvHalo(i) % GEleIDX(n))
      
           CALL MPI_IRECV(RecvHalo(i)  % GEleIDX, n, MPI_INTEGER, i-1, 195, ELMER_COMM_WORLD, &
              status(i), ierr)
           CALL MPI_SEND(halo(i) % GEleIDX,k, MPI_INTEGER, i-1, 195, ELMER_COMM_WORLD, ierr)
         END DO
      
         CALL MPI_Waitall(ParEnv % PEs, status(1:ParEnv % PEs), MPI_STATUSES_IGNORE, ierr)
         status = MPI_REQUEST_NULL
      
         DO i=1,ParEnv % PEs
            if (i.EQ.(ParEnv%MyPE+1)) CYCLE

           k = Halo(i) % count
           n = RecvHalo(i) % count
      
           IF (k == 0) CYCLE
           !! 
           !! If should keep the intersection
           allocate(keep(k))
           DO j=1,k
            keep(j) = any(halo(i) % GEleIDX(j) == RecvHalo(i) % GEleIDX)
           END DO
           ! size of the intersection
           l=count(keep)
           IF (l /= k) THEN
                   allocate(tmp(k),tmp2(k))
                   tmp(1:k)=halo(i) % GEleIDX(1:k)
                   tmp2(1:k)=halo(i) % EleIDX(1:k)
      
                   deallocate(halo(i) % GEleIDX,halo(i) % EleIDX)
                   ALLOCATE(Halo(i) % GEleIDX(l),Halo(i) % EleIDX(l))
      
                   Halo(i) % count = l
                   cpt=1
                   DO j=1,k
                      IF (.NOT.keep(j)) CYCLE
                      halo(i) % GEleIDX(cpt)=tmp(j)
                      halo(i) % EleIDX(cpt)=tmp2(j)
                      cpt=cpt+1
                   END DO
                   deallocate(tmp,tmp2)
           END IF
           deallocate(keep)

         END DO
      
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         ! write some debugging if required
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         IF (DEBUG) THEN
            DO i=1,ParEnv % PEs

              PRINT *,ParEnv%MyPE," sharing ",Halo(i) % count," elements with partition ",i-1

              open(10,file="Halo."//I2S(ParEnv % MyPE+1)//"."//I2S(i)//".dat")
              DO j=1,Halo(i) % count
                 Element => Mesh % Elements(Halo(i) % EleIDX(j))
                 write(10,*) halo(i) % GEleIDX(j), Halo(i) % EleIDX(j), Element % PartIndex
              END DO
              close(10)
            END DO
         END IF
      
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         ! clean temporary arrays
         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         DEALLOCATE(MeshHalo)
         DEALLOCATE(RecvHalo)
         DEALLOCATE(HaloIndexes)
         DEALLOCATE(status)
           
         CALL MPI_BARRIER(ELMER_COMM_WORLD,ierr)

         CALL INFO(SolverName,"DETECT HALO ELEMENTS - OUT",level=5)
      
      END SUBROUTINE DetectHalo

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! COLLECTION OF SUBROUTINES FOR THE CONNECTION DETECTION
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      SUBROUTINE InitRegion(Region,label)
         TYPE(Region_t), ALLOCATABLE,INTENT(OUT) :: Region(:)
         INTEGER,INTENT(IN) :: label
     
         ALLOCATE(Region(label))
           
         Region(:) % Area = 0._dp
         Region(:) % NoE = 0
         Region(:) % Tag = huge(label)
     
      END SUBROUTINE InitRegion
     
      SUBROUTINE QueueInit(Queue,n)
         IMPLICIT NONE
         TYPE(Queue_t),INTENT(OUT) :: Queue
         INTEGER,INTENT(IN) :: n
           ALLOCATE(Queue%items(n))
           Queue%top=0
           Queue%maxsize=n
      END SUBROUTINE QueueInit
     
      SUBROUTINE QueuePush(Queue,x)
         IMPLICIT NONE
         TYPE(Queue_t) :: Queue
         INTEGER :: x
           IF (Queue%top.EQ.Queue%maxsize) &
             CALL FATAL('QueuePush','Too many elements in the queue?')
     
           Queue%top=Queue%top+1
           Queue%items(Queue%top)=x
     
      END SUBROUTINE QueuePush
     
      SUBROUTINE QueuePop(Queue,x)
         IMPLICIT NONE
         TYPE(Queue_t) :: Queue
         INTEGER :: x
           IF (Queue%top.EQ.0) &
             CALL FATAL('QueuePop','No more element in the queue')
     
           x=Queue%items(Queue%top)
           Queue%top=Queue%top-1
      END SUBROUTINE QueuePop

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! FIND unique values in an integer array
!  INPUT :: 
!     n  : array size
!     val(n): input array
!  OUTPUT :: 
!     final :: output array with unique values in increasing order
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine unique_sort(n,val,final)
         implicit none
         INTEGER,INTENT(IN) :: n
         INTEGER, dimension(n),INTENT(IN) :: val
         INTEGER, dimension(:), allocatable,INTENT(OUT) :: final

         INTEGER, dimension(n) :: unique
         INTEGER :: i , min_val, max_val

         i = 0
         min_val = minval(val)-1
         max_val = maxval(val)
         do while (min_val<max_val)
            i = i+1
            min_val = minval(val, mask=val>min_val)
            unique(i) = min_val
         enddo
         allocate(final(i), source=unique(1:i))  
      end subroutine unique_sort


end module ConnectedAreas
