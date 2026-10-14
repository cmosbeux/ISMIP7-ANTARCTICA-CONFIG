!/*****************************************************************************/
! *
! *  SSACalving: thickness-based calving of floating elements connected to the ice front
! *
! *  A floating element (GroundedMask below threshold) is a calving candidate when its mean
! *  thickness is below 'Critical Thickness'. Candidates connected to the ice front through
! *  a chain of candidates are calved according to 'Calving Thickness Mode':
! *    none    : only flag the elements in the calving variable
! *    passive : flag the elements, to be used as a passive condition
! *              (e.g. "H Passive = Variable CalvingMask" + Active/Passive boundary condition)
! *    minimum : set nodal thickness to 'Calving Min Thickness' (or H Lower Limit / Min H)
! *    factor  : multiply nodal thickness by 'Calving Thickness Factor' (rapid thinning)
! *
! *  Passive mode:
! *  -------------
! *  a configurable inner buffer of thin front cells remains active
! *  rather than being constrained to H=1 and zero velocity. This gives H and velocity
! *  a chance to evolve in the buffer. Previously passive cells are reactivated one edge
! *  layer at a time when a neighboring active cell reaches 'Recovery Thickness'. Use
! *  Recovery Thickness > Critical Thickness for hysteresis. 
! *
! *  minimum and factor modes:
! *  ------------------------
! *  these modes directly modify the nodal thickness of calving candidates.
! *  minimum mode sets the thickness to 'Calving Min Thickness'.
! *  factor mode multiplies the thickness by 'Calving Thickness Factor'.
! *   
! *   /!\ with these two modes the calving buffer is not used. 
! *
! *  ---------------------------------------------------------------------------
! *  Calving variable values: -1 (grounded), 0 (floating and intact), 1 (calved)
! *  ---------------------------------------------------------------------------
! *****************************************************************************/


      SUBROUTINE SSACalving(Model,Solver,dt,TransientSimulation)
      USE DefUtils
      USE ConnectedAreas
      IMPLICIT NONE

      TYPE(Model_t) :: Model
      TYPE(Solver_t), TARGET :: Solver
      REAL(KIND=dp) :: dt
      LOGICAL :: TransientSimulation

      TYPE Send_t
         INTEGER, ALLOCATABLE :: val(:)
      END TYPE Send_t

      TYPE(HaloShare_t), ALLOCATABLE, SAVE :: Halo(:)
      TYPE(Send_t), ALLOCATABLE :: Send(:), Recv(:)
      TYPE(Queue_t) :: Queue
      TYPE(Variable_t), POINTER :: HVar, GroundedMaskVar, GroundedMaskElemVar, CalvingVar
      TYPE(Mesh_t), POINTER :: Mesh
      TYPE(Element_t), POINTER :: Element, Parent
      TYPE(Element_t), POINTER :: Face
      TYPE(ValueList_t), POINTER :: SolverParams, BodyForce, Material
      REAL(KIND=dp), ALLOCATABLE :: MinHLocal(:)
      LOGICAL, ALLOCATABLE :: NodeUpdated(:)
      LOGICAL, ALLOCATABLE :: Floating(:), Candidate(:), Connected(:), PrevCalved(:), Recovered(:)
      LOGICAL, ALLOCATABLE :: Buffer(:), BufferFront(:)
      INTEGER, ALLOCATABLE :: req(:)
      REAL(KIND=dp), ALLOCATABLE :: MeanH(:)
      REAL(KIND=dp) :: critical_h, recovery_h, groundedmask_threshold
      REAL(KIND=dp) :: calving_h_factor, calving_h_minimum
      REAL(KIND=dp) :: gmask_sum, hsum, hmax
      INTEGER :: n, t, e, pe, i, side, k, node, knode, nvalid, nfaces
      INTEGER :: nSize, EIndex, nCalved, nCalvedGlobal, ierr
      INTEGER :: buffer_layers, layer
      LOGICAL :: Found, GotIt, Parallel, Converged, AllConverged
      LOGICAL :: h_is_passive, h_is_minimum, h_is_factor, h_use
      LOGICAL :: calving_h_minimum_found, IsFront, hmax_is_defined, meanh_is_defined, mean_front_thickness
      CHARACTER(LEN=MAX_NAME_LEN) :: SolverName = 'SSACalving'
      CHARACTER(LEN=MAX_NAME_LEN) :: GroundedMaskVarName, GroundedMaskElemVarName
      CHARACTER(LEN=MAX_NAME_LEN) :: HVarName, CalvingVarName, CalvingHMode

      Mesh => Solver % Mesh
      SolverParams => GetSolverParams()
      nSize = Mesh % NumberOfBulkElements
      Parallel = (ParEnv % PEs > 1)

      critical_h = ListGetCReal(SolverParams,'Critical Thickness',Found)
      IF (.NOT.Found) CALL FATAL(SolverName,'Critical Thickness must be set')

      ! Recovery is the higher re-advance threshold; default it above calving.
      ! Reovery occurs when the thickness exceeds the recovery threshold at the calving front edge
      ! /!\ The front recovery is probably sensitive to the choice of recovery thickness
      recovery_h = ListGetCReal(SolverParams,'Recovery Thickness',Found)
      IF (.NOT.Found) recovery_h = critical_h + MAX(0.1_dp*critical_h,1._dp)

      ! The number of recovering cells is determined by the calving buffer layers 
      ! (~x elements from the calving front)
      ! Default number of buffer layers is 2
      ! Too large a number of buffer layers may result in an unrealistically large thin layer at the front
      buffer_layers = ListGetInteger(SolverParams,'Calving Buffer Layers',Found)
      IF (.NOT.Found) buffer_layers = 2
      IF (buffer_layers.LT.0) &
         CALL FATAL(SolverName,'Calving Buffer Layers cannot be negative')

      ! Threshold for considering an element as grounded (default 0)
      groundedmask_threshold = ListGetCReal(SolverParams,'GroundedMask Threshold',Found)
      IF (.NOT.Found) groundedmask_threshold = 0._dp

      GroundedMaskVarName = ListGetString(SolverParams,'GroundedMask Variable',Found)
      IF (.NOT.Found) GroundedMaskVarName = 'GroundedMask'
      GroundedMaskElemVarName = TRIM(GroundedMaskVarName)//'_Elem'

      CalvingVarName = ListGetString(SolverParams,'Calving Variable',Found)
      IF (.NOT.Found) CalvingVarName = 'CalvingMask'

      HVarName = ListGetString(SolverParams,'Thickness Variable',Found)
      IF (.NOT.Found) HVarName = 'H'

      CalvingHMode = ListGetString(SolverParams,'Calving Thickness Mode',Found)
      IF (.NOT.Found) CalvingHMode = 'none'
      
      ! Calving thickness Factor will be used if CalvingHmode is 'factor'
      calving_h_factor = ListGetCReal(SolverParams,'Calving Thickness Factor',Found)
      IF (.NOT.Found) calving_h_factor = 0.5_dp

      ! Calving minimum thickness will be used if CalvingHmode is 'minimum'
      calving_h_minimum = ListGetCReal(SolverParams,'Calving Min Thickness',Found)
      calving_h_minimum_found = Found

      ! Determine the method for calculating the front thickness
      ! /!\ for the minimum mode, the mean front thickness should not be used
      !     it would averaging nodes H>=Hcritrical and H=1, usually leading to Hmean< Hcritrical
      !     This automatically triggers a retreat. 
      !     Setting Mean Front Thickness to .FALSE. will use the maximum nodal H instead and 
      !     avoid the premature retreat due to averaging. In series, the behavior is also much similar 
      !     to the passive mode with a buffer zone
      mean_front_thickness = ListGetLogical(SolverParams,'Mean Front Thickness',Found)
      IF (.NOT.Found) THEN
         hmax_is_defined = .TRUE.
         meanh_is_defined = .FALSE.
      ELSEIF (mean_front_thickness) THEN
         hmax_is_defined = .FALSE.
         meanh_is_defined = .TRUE.
      ELSE
         hmax_is_defined = .TRUE.
         meanh_is_defined = .FALSE.
      END IF


      h_is_passive = (TRIM(CalvingHMode).EQ.'passive')
      h_is_minimum = (TRIM(CalvingHMode).EQ.'minimum')
      h_is_factor  = (TRIM(CalvingHMode).EQ.'factor')

      IF (h_is_passive .AND. recovery_h.LE.critical_h) &
         CALL FATAL(SolverName,'Passive calving requires Recovery Thickness > Critical Thickness')

      h_use = .FALSE.
      IF (TRIM(CalvingHMode).EQ.'none') THEN
         h_use = .FALSE.
      ELSE IF (h_is_passive) THEN
         h_use = .FALSE.
      ELSE IF (h_is_minimum .OR. h_is_factor) THEN
         h_use = .TRUE.
      ELSE
         CALL FATAL(SolverName,'Calving Thickness Mode should be one of: none, passive, minimum, factor')
      END IF

      IF (h_is_factor) THEN
         IF (calving_h_factor.LE.0._dp .OR. calving_h_factor.GT.1._dp) &
            CALL FATAL(SolverName,'Calving Thickness Factor should be in ]0,1]')
      END IF

      ! Get the thickness variable
      HVar => VariableGet(Mesh % Variables,TRIM(HVarName),UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(HVar%Perm)) &
         CALL FATAL(SolverName,TRIM(HVarName)//' has no valid permutation')
      IF (HVar%TYPE.NE.Variable_on_nodes) &
         CALL FATAL(SolverName,TRIM(HVarName)//' should be on_nodes')

      ! Get the grounded mask variable
      GroundedMaskVar => VariableGet(Mesh % Variables,TRIM(GroundedMaskVarName),UnfoundFatal=.TRUE.)
      IF (.NOT.ASSOCIATED(GroundedMaskVar%Perm)) &
         CALL FATAL(SolverName,TRIM(GroundedMaskVarName)//' has no valid permutation')

      GroundedMaskElemVar => EVarGet(Solver,TRIM(GroundedMaskElemVarName),nSize,.TRUE.)

      ! /!\ Some attempt to get the passive mode work in parallel through some dimension test
      ! Right now, there seems to have an issue about the number of elements in parallel with the halos.
      ! If CalvingVar is exported, there is a size mismatch between the exported variable and nSize

      ! CalvingVar => VariableGet(Mesh % Variables,TRIM(CalvingVarName),UnfoundFatal=.TRUE.)
      ! print *, 'nSize =', nSize, SIZE(CalvingVar%Perm)
      CalvingVar => EVarGet(Solver,TRIM(CalvingVarName),nSize,.TRUE.)
      
      IF (.NOT.ASSOCIATED(CalvingVar%Perm)) &
         CALL FATAL(SolverName,TRIM(CalvingVarName)//' has no valid permutation')
      IF (CalvingVar%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,TRIM(CalvingVarName)//' should be on_elements')

      ALLOCATE(Floating(nSize),Candidate(nSize),Connected(nSize),PrevCalved(nSize), &
            Recovered(nSize),Buffer(nSize),BufferFront(nSize),MeanH(nSize))
      MeanH = -1._dp
      Floating = .FALSE.
      Candidate = .FALSE.
      Connected = .FALSE.
      PrevCalved = .FALSE.
      Recovered = .FALSE.
      Buffer = .FALSE.
      BufferFront = .FALSE.

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Floating mask per element (same convention as CollapseAreas)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         IF (GroundedMaskVar%TYPE .EQ. Variable_on_elements) THEN
            k = GroundedMaskVar % Perm(EIndex)
            IF (k.GT.0) Floating(EIndex) = (GroundedMaskVar % Values(k) .LE. groundedmask_threshold)
         ELSE IF (GroundedMaskVar%TYPE .EQ. Variable_on_nodes) THEN
            n = GetElementNOFNodes(Element)
            gmask_sum = 0._dp
            nvalid = 0
            DO i=1,n
               knode = GroundedMaskVar % Perm(Element % NodeIndexes(i))
               IF (knode.GT.0) THEN
                  gmask_sum = gmask_sum + GroundedMaskVar % Values(knode)
                  nvalid = nvalid + 1
               END IF
            END DO
            ! If nvalid is greater than 0, floating if average grounded mask is LE the threshold
            IF (nvalid.GT.0) Floating(EIndex) = ((gmask_sum / nvalid) .LE. groundedmask_threshold)
         ELSE
            CALL FATAL(SolverName,TRIM(GroundedMaskVarName)//' should be on_nodes or on_elements')
         END IF
         
         GroundedMaskElemVar % Values(GroundedMaskElemVar % Perm(EIndex)) = MERGE(-1._dp,1._dp,Floating(EIndex))
      END DO

      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         n = GetElementNOFNodes(Element)
         hsum = 0._dp
         hmax = -HUGE(0._dp)
         nvalid = 0
         DO i=1,n
            knode = HVar % Perm(Element % NodeIndexes(i))
            IF (knode.GT.0) THEN
               hsum = hsum + HVar % Values(knode)
               nvalid = nvalid + 1
               hmax = MAX(hmax, HVar % Values(knode))
            END IF
         END DO
         IF (meanh_is_defined) THEN
            IF (nvalid.GT.0) MeanH(EIndex) = hsum / REAL(nvalid,dp)
         ELSEIF (hmax_is_defined) THEN
            IF (nvalid.GT.0) MeanH(EIndex) = hmax
         END IF

      END DO

      ! Step 1: Check the previous calving mask
      DO t=1,nSize
         EIndex = Mesh % Elements(t) % ElementIndex
         PrevCalved(EIndex) = (CalvingVar % Values(CalvingVar % Perm(EIndex)) .GT. 0.5_dp)
      END DO

      ! Step 2: reactivate one passive edge-cell when it touches active floating
      ! ice that evolved to H >= recovery_h. H can then evolve normally through advection
      ! on the next thickness solver call
      
      CALL FindMeshEdges(Mesh,.FALSE.)
      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         IF (.NOT.PrevCalved(EIndex)) CYCLE
         IF (.NOT.Floating(EIndex)) THEN
            PrevCalved(EIndex) = .FALSE.
            CYCLE
         END IF
         IF (.NOT.h_is_passive) THEN
            IF (MeanH(EIndex).GE.recovery_h) PrevCalved(EIndex) = .FALSE.
            CYCLE
         END IF
         nfaces = NumberOfFaces(Mesh,Element)
         DO i=1,nfaces
            Face => GetFace(Mesh,Element,i)
            DO side=1,2
               IF (side.EQ.1) THEN
                  Parent => Face % BoundaryInfo % Left
               ELSE
                  Parent => Face % BoundaryInfo % Right
               END IF
               IF (.NOT.ASSOCIATED(Parent)) CYCLE
               pe = Parent % ElementIndex
               IF (pe.EQ.EIndex .OR. PrevCalved(pe)) CYCLE
               IF (.NOT.Floating(pe)) CYCLE
               IF (MeanH(pe).LT.recovery_h) CYCLE
               PrevCalved(EIndex) = .FALSE.
               Recovered(EIndex) = .TRUE.
               EXIT
            END DO
            IF (Recovered(EIndex)) EXIT
         END DO
      END DO

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Candidates: floating elements thinner than the critical thickness and not calved yet
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      DO t=1,nSize
         EIndex = Mesh % Elements(t) % ElementIndex
         IF (.NOT.Floating(EIndex)) CYCLE
         IF (PrevCalved(EIndex)) CYCLE
         IF (Recovered(EIndex)) CYCLE
         IF (MeanH(EIndex).LT.0._dp) CYCLE
         Candidate(EIndex) = (MeanH(EIndex) .LT. critical_h)
      END DO

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Connectivity of candidates to the ice front
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      CALL FindMeshEdges(Mesh,.FALSE.)
      CALL QueueInit(Queue,nSize)

      ! Check if element has a face on the mesh boundary or next to a calved element
      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         IF (.NOT.Candidate(EIndex)) CYCLE
         IF (Parallel) THEN
            IF (Element % PartIndex /= ParEnv % MyPE) CYCLE
         END IF

         !
         IsFront = .FALSE.
         nfaces = NumberOfFaces(Mesh,Element)
         DO i=1,nfaces
            Face => GetFace(Mesh,Element,i)
            ! Check if the face is on the mesh boundary
            IF (.NOT.ASSOCIATED(Face % BoundaryInfo % Left) .OR. &
                .NOT.ASSOCIATED(Face % BoundaryInfo % Right)) THEN
               IsFront = .TRUE.
            ELSE
               ! Check if the face is next to a calved element
               DO side=1,2
                  IF (side.EQ.1) THEN
                     Parent => Face % BoundaryInfo % Left
                  ELSE
                     Parent => Face % BoundaryInfo % Right
                  END IF
                  IF (Parent % ElementIndex.NE.EIndex) THEN
                     IF (PrevCalved(Parent % ElementIndex)) IsFront = .TRUE.
                  END IF
               END DO
            END IF
            IF (IsFront) EXIT
         END DO

         ! If the element is connected to the front, mark it and add to the queue
         IF (IsFront) THEN
            Connected(EIndex) = .TRUE.
            e = EIndex
            CALL QueuePush(Queue,e)
         END IF
      END DO

      IF (Parallel) THEN
         IF (.NOT.ALLOCATED(Halo)) CALL DetectHalo(Solver,Halo)
         ALLOCATE(req(ParEnv % PEs),Send(ParEnv % PEs),Recv(ParEnv % PEs))
         DO i=1,ParEnv % PEs
            ALLOCATE(Send(i) % val(Halo(i) % count),Recv(i) % val(Halo(i) % count))
         END DO
      END IF

      DO
         ! Propagate through thin elements
         DO WHILE (Queue%top.GT.0)
            CALL QueuePop(Queue,e)
            Element => Mesh % Elements(e)
            nfaces = NumberOfFaces(Mesh,Element)
            DO i=1,nfaces
               Face => GetFace(Mesh,Element,i)
               DO side=1,2
                  IF (side.EQ.1) THEN
                     Parent => Face % BoundaryInfo % Left
                  ELSE
                     Parent => Face % BoundaryInfo % Right
                  END IF
                  IF (.NOT.ASSOCIATED(Parent)) CYCLE
                  pe = Parent % ElementIndex
                  IF (pe.EQ.e) CYCLE
                  IF (Candidate(pe) .AND. .NOT.Connected(pe)) THEN
                     Connected(pe) = .TRUE.
                     CALL QueuePush(Queue,pe)
                  END IF
               END DO
            END DO
         END DO

         IF (.NOT.Parallel) EXIT

         ! Share the connected flag with halo
         DO i=1,ParEnv % PEs
            CALL MPI_IRECV(Recv(i) % val,Halo(i) % count,MPI_INTEGER,i-1,999,ELMER_COMM_WORLD,req(i),ierr)
         END DO
         DO i=1,ParEnv % PEs
            DO k=1,Halo(i) % count
               Send(i) % val(k) = MERGE(1,0,Connected(Halo(i) % EleIDX(k)))
            END DO
            CALL MPI_SEND(Send(i) % val,Halo(i) % count,MPI_INTEGER,i-1,999,ELMER_COMM_WORLD,ierr)
         END DO
         CALL MPI_WAITALL(ParEnv % PEs,req,MPI_STATUSES_IGNORE,ierr)

         ! At this point, all halo elements have been updated with the connected status from neighboring PEs
         Converged = .TRUE.
         DO i=1,ParEnv % PEs
            DO k=1,Halo(i) % count
               pe = Halo(i) % EleIDX(k)
               IF (Recv(i) % val(k).EQ.1 .AND. Candidate(pe) .AND. .NOT.Connected(pe)) THEN
                  Connected(pe) = .TRUE.
                  CALL QueuePush(Queue,pe)
                  Converged = .FALSE.
               END IF
            END DO
         END DO
         CALL MPI_ALLREDUCE(Converged,AllConverged,1,MPI_LOGICAL,MPI_LAND,ELMER_COMM_WORLD,ierr)
         IF (AllConverged) EXIT
      END DO

      ! Step 3 (only for passive mode)
      ! ------------------------------
      ! keep the ice-side layers of the connected thin band active. These
      ! cells are the refill "buffer": unlike passive cells, they continue to receive
      ! thickness and velocity updates. Seed layer 1 next to intact active ice, then
      ! expand outward by edge adjacency for the requested number of layers.
      IF (h_is_passive .AND. buffer_layers.GT.0) THEN
         DO t=1,nSize
            EIndex = Mesh % Elements(t) % ElementIndex
            IF (.NOT.Candidate(EIndex) .OR. .NOT.Connected(EIndex)) CYCLE
            Element => Mesh % Elements(t)
            nfaces = NumberOfFaces(Mesh,Element)
            DO i=1,nfaces
               Face => GetFace(Mesh,Element,i)
               DO side=1,2
                  IF (side.EQ.1) THEN
                     Parent => Face % BoundaryInfo % Left
                  ELSE
                     Parent => Face % BoundaryInfo % Right
                  END IF
                  IF (.NOT.ASSOCIATED(Parent)) CYCLE
                  pe = Parent % ElementIndex
                  IF (pe.EQ.EIndex .OR. PrevCalved(pe)) CYCLE
                  IF (.NOT.Floating(pe)) CYCLE
                  IF (.NOT.Candidate(pe)) Buffer(EIndex) = .TRUE.
               END DO
            END DO
         END DO

         ! Grow the bufffer layer from the initial thin band limit
         DO layer=2,buffer_layers
            BufferFront = Buffer  
            IF (Parallel) THEN
               DO i=1,ParEnv % PEs
                  CALL MPI_IRECV(Recv(i) % val,Halo(i) % count,MPI_INTEGER,i-1,666, &
                       ELMER_COMM_WORLD,req(i),ierr)
               END DO
               DO i=1,ParEnv % PEs
                  DO k=1,Halo(i) % count
                     Send(i) % val(k) = MERGE(1,0,Buffer(Halo(i) % EleIDX(k)))
                  END DO
                  CALL MPI_SEND(Send(i) % val,Halo(i) % count,MPI_INTEGER,i-1,666, &
                       ELMER_COMM_WORLD,ierr)
               END DO
               CALL MPI_WAITALL(ParEnv % PEs,req,MPI_STATUSES_IGNORE,ierr)
               DO i=1,ParEnv % PEs
                  DO k=1,Halo(i) % count
                     IF (Recv(i) % val(k).EQ.1) BufferFront(Halo(i) % EleIDX(k)) = .TRUE.
                  END DO
               END DO
            END IF

            
            DO t=1,nSize
               EIndex = Mesh % Elements(t) % ElementIndex
               IF (.NOT.Candidate(EIndex) .OR. .NOT.Connected(EIndex)) CYCLE
               IF (Buffer(EIndex)) CYCLE
               Element => Mesh % Elements(t)
               nfaces = NumberOfFaces(Mesh,Element)
               DO i=1,nfaces
                  Face => GetFace(Mesh,Element,i)
                  DO side=1,2
                     IF (side.EQ.1) THEN
                        Parent => Face % BoundaryInfo % Left
                     ELSE
                        Parent => Face % BoundaryInfo % Right
                     END IF
                     IF (.NOT.ASSOCIATED(Parent)) CYCLE
                     pe = Parent % ElementIndex
                     IF (pe.EQ.EIndex) CYCLE
                     IF (BufferFront(pe)) Buffer(EIndex) = .TRUE.
                  END DO
               END DO
            END DO
         END DO
      END IF

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Apply calving
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      n = MAX(Mesh % MaxElementNodes,Mesh % MaxElementDOFs)
      ALLOCATE(MinHLocal(n))
      IF (h_use) THEN
         ALLOCATE(NodeUpdated(SIZE(HVar%Perm)))
         NodeUpdated = .FALSE.
      END IF

      nCalved = 0
      DO t=1,nSize
         Element => Mesh % Elements(t)
         EIndex = Element % ElementIndex
         k = CalvingVar % Perm(EIndex)
         IF (k.LE.0) CYCLE

         IF (PrevCalved(EIndex) .OR. (Connected(EIndex) .AND. .NOT.Buffer(EIndex))) THEN
            CalvingVar % Values(k) = 1._dp
         ELSE IF (Floating(EIndex)) THEN
            CalvingVar % Values(k) = 0._dp
         ELSE
            CalvingVar % Values(k) = -1._dp
         END IF

         IF (.NOT.Connected(EIndex) .OR. Buffer(EIndex)) CYCLE
         IF (Parallel) THEN
            IF (Element % PartIndex == ParEnv % MyPE) nCalved = nCalved + 1
         ELSE
            nCalved = nCalved + 1
         END IF

         IF (.NOT.h_use) CYCLE
         n = GetElementNOFNodes(Element)

         IF (h_is_minimum) THEN
            IF (calving_h_minimum_found) THEN
               MinHLocal(1:n) = calving_h_minimum
            ELSE
               BodyForce => GetBodyForce(Element)
               Material => GetMaterial(Element)
               MinHLocal(1:n) = ListGetConstReal(BodyForce,'H Lower Limit',GotIt)
               IF (.NOT.GotIt) MinHLocal(1:n) = ListGetConstReal(Material,'Min H',GotIt)
               IF (.NOT.GotIt) CALL FATAL(SolverName, &
                  & 'Calving Mode=minimum requires Calving Min Thickness or local H lower limit')
            END IF
         END IF

         DO i=1,n
            node = Element % NodeIndexes(i)
            IF (node.LE.0) CYCLE
            IF (node.GT.SIZE(HVar%Perm)) CYCLE
            knode = HVar % Perm(node)
            IF (knode.LE.0) CYCLE
            IF (NodeUpdated(knode)) CYCLE

            IF (h_is_minimum) THEN
               HVar % Values(knode) = MinHLocal(i)
            ELSE IF (h_is_factor) THEN
               HVar % Values(knode) = calving_h_factor * HVar % Values(knode)
               IF (HVar % Values(knode) < 1.0_dp) HVar % Values(knode) = 1.0_dp
            END IF
            NodeUpdated(knode) = .TRUE.
         END DO
      END DO

      nCalvedGlobal = nCalved
      IF (Parallel) &
         CALL MPI_ALLREDUCE(nCalved,nCalvedGlobal,1,MPI_INTEGER,MPI_SUM,ELMER_COMM_WORLD,ierr)
      WRITE(Message,'(A)') 'Calving: '//I2S(nCalvedGlobal)//' elements connected to the front below critical thickness'
      CALL INFO(SolverName,Message,level=3)

      CALL DEALLOCATE_QUEUE()
      DEALLOCATE(Floating,Candidate,Connected,PrevCalved,Recovered,Buffer,BufferFront,MeanH,MinHLocal)
      IF (h_use) DEALLOCATE(NodeUpdated)
      IF (Parallel) DEALLOCATE(req,Send,Recv)

      CONTAINS

      SUBROUTINE DEALLOCATE_QUEUE()
         IF (ALLOCATED(Queue%items)) DEALLOCATE(Queue%items)
      END SUBROUTINE DEALLOCATE_QUEUE

      INTEGER FUNCTION NumberOfFaces(M,El)
         TYPE(Mesh_t), POINTER :: M
         TYPE(Element_t), POINTER :: El
         IF (M % MeshDim.EQ.2) THEN
            NumberOfFaces = El % TYPE % NumberOfEdges
         ELSE
            NumberOfFaces = El % TYPE % NumberOfFaces
         END IF
      END FUNCTION NumberOfFaces

      FUNCTION GetFace(M,El,idx) RESULT(F)
         TYPE(Mesh_t), POINTER :: M
         TYPE(Element_t), POINTER :: El
         INTEGER :: idx
         TYPE(Element_t), POINTER :: F
         IF (M % MeshDim.EQ.2) THEN
            F => M % Edges(El % EdgeIndexes(idx))
         ELSE
            F => M % Faces(El % FaceIndexes(idx))
         END IF
         IF (.NOT.ASSOCIATED(F)) CALL FATAL('SSACalving','Face not found')
      END FUNCTION GetFace

      END SUBROUTINE SSACalving