SUBROUTINE INITMIP_Scalar_OUTPUT( Model,Solver,dt,TransientSimulation )
  USE DefUtils
  IMPLICIT NONE

  TYPE(Model_t) :: Model
  TYPE(Solver_t):: Solver
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation

  TYPE(Variable_t),POINTER :: GMVAR,FlowVar,HVar,HRVar,BedVar,DHDTVar,BasinVar,IceDis
  INTEGER,POINTER :: Permutation(:)

  REAL(KIND=dp),SAVE,ALLOCATABLE :: Volume(:),VAF(:)
  REAL(KIND=dp),SAVE,ALLOCATABLE :: DHDTFlux(:),SMBFlux(:),BMBFlux(:),HMinFlux(:)
  REAL(KIND=dp),SAVE,ALLOCATABLE :: GroundedArea(:),FloatingArea(:),FreeArea(:)
  REAL(KIND=dp),SAVE,ALLOCATABLE :: CalvingFlux(:)
  REAL(KIND=dp),SAVE,ALLOCATABLE :: GLFlux(:)
  REAL(KIND=dp),SAVE :: zsea,rhow
  REAL(KIND=dp) :: ztmp

  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: NodeArea
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: LocalArea
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: NodalH,NodalDHDT,MinH,NodalGM
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: NodalSMB,NodalBMB,NodalMB
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: NodalHf
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: rhoi
  REAL (KIND=dp), ALLOCATABLE, DIMENSION(:),SAVE :: Val,ParVal
  REAL(KIND=dp),ALLOCATABLE,SAVE :: Basis(:), dBasisdx(:,:)

  INTEGER :: i,m,n, maxbastmp,kk
  INTEGER, SAVE :: kmax
  INTEGER :: ierr
  INTEGER :: NVal=12
  INTEGER, PARAMETER :: io=12
  INTEGER,PARAMETER :: DIM=2 !dimension of the pb restricted to 2 currently

  INTEGER :: FlowDofs

  LOGICAL,SAVE :: Firsttime=.TRUE.,  BasinLogic =.TRUE.

  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='INITMIP_Scalar_OUTPUT',xi
  CHARACTER(LEN=MAX_NAME_LEN),SAVE :: OUTPUT_FName, OUTPUT_FName_b
  CHARACTER(LEN=MAX_NAME_LEN),ALLOCATABLE,SAVE :: ValueNames(:)

  CALL GET_VARIABLES()

  IF (Firsttime.OR.Solver%Mesh%Changed) THEN

     IF (.NOT.ASSOCIATED(Solver%Variable)) & 
          CALL FATAL(SolverName,'Solver%Variable Not associated')
     IF (.NOT.ASSOCIATED(Solver%Matrix)) &
          CALL FATAL(SolverName,'Solver%Matrix Not associated')

     IF ( CurrentCoordinateSystem() /= Cartesian )  &
          CALL FATAL(SolverName,'Only For cartesian system')

     IF ( Model % Mesh % MeshDim /= DIM ) &
          CALL FATAL(SolverName,'Only For 2D plan view')
     IF (.NOT.ASSOCIATED(BasinVar)) THEN
        kmax=1
     ELSE
        maxbastmp = MAXVAL(BasinVar % Values)+1
     END IF
        
     IF  (ParEnv % PEs > 1 )THEN
        CALL MPI_ALLREDUCE(maxbastmp,kmax,1,MPI_INTEGER,MPI_MAX,ELMER_COMM_WORLD,ierr)
     ELSE
        kmax=maxbastmp
     END IF

     !## DO SOME ALLOCATION
     CALL DO_ALLOCATION(Firsttime)

     !## Name of Saved variables
     ValueNames(1)='Volume'
     ValueNames(2)='Volume Above Floatation'
     ValueNames(3)='Volume rate of change'
     ValueNames(4)='SMB Flux'
     ValueNames(5)='BMB Flux'
     ValueNames(6)='Residual Flux'
     ValueNames(7)='Ice Discharge'
     ValueNames(8)='Ice flux at Grounding Line'
     ValueNames(9)='Grounded ice area'
     ValueNames(10)='Floating ice area'
     ValueNames(11)='Ice Free area'
     ValueNames(12)='Mean Basal Melt'


     IF (Firsttime) CALL GET_CONSTANTS(zsea,rhow)

     IF (Firsttime) CALL INIT_OUTPUT_FILE(OUTPUT_FName)
     IF (Firsttime) CALL COMPUTE_NodeArea(NodeArea)
     Firsttime=.FALSE.          
  END IF
  
  CALL BODY_INTEGRATION(Volume,VAF,DHDTFlux,SMBFlux,BMBFlux,HMinFlux,&
       GroundedArea,FloatingArea,FreeArea)

  CALL BC_INTEGRATION(CalvingFlux)

  CALL COMPUTE_GL_FLUX(GLFlux)

  DO kk=0,kmax-1

     IF (kk == 0) THEN
        Val(1)=SUM(Volume(:))
        Val(2)=SUM(VAF(:))

        Val(3)=SUM(DHDTFlux(:))
        Val(4)=SUM(SMBFlux(:))
        Val(5)=SUM(BMBFlux(:))
        Val(6)=SUM(HMinFlux(:))

        Val(7)=SUM(CalvingFlux(:))
        Val(8)= SUM(GLFlux(:))

        Val(9)=SUM(GroundedArea(:))
        Val(10)=SUM(FloatingArea(:))
        Val(11)=SUM(FreeArea(:))

        CALL MPI_ALLREDUCE(Val,ParVal,NVal,MPI_DOUBLE_PRECISION,MPI_SUM,ELMER_COMM_WORLD,ierr)
        Val=ParVal

        Val(12)=Val(5)/Val(10)
     ELSE
        

        Val(1)=Volume(kk)
        Val(2)=VAF(kk)

        Val(3)=DHDTFlux(kk)
        Val(4)=SMBFlux(kk)
        Val(5)=BMBFlux(kk)
        Val(6)=HMinFlux(kk)

        Val(7)=CalvingFlux(kk)
        Val(8)= GLFlux(kk)

        Val(9)=GroundedArea(kk)
        Val(10)=FloatingArea(kk)
        Val(11)=FreeArea(kk)

        CALL MPI_ALLREDUCE(Val,ParVal,NVal,MPI_DOUBLE_PRECISION,MPI_SUM,ELMER_COMM_WORLD,ierr)
        Val=ParVal

        Val(12)=Val(5)/Val(10)
     END IF
  

     IF ((ParEnv % PEs > 1 ).AND.(ParEnv % MyPe.NE.0)) CYCLE

     write(xi ,'(I0)')kk
     IF (kk < 10 ) THEN
        OUTPUT_FName_b ='Basin0'//TRIM(xi)//TRIM(OUTPUT_FName)
     ELSE
        OUTPUT_FName_b ='Basin'//TRIM(xi)//TRIM(OUTPUT_FName)
     END IF
     
     IF( Solver % TimesVisited > 0 ) THEN
        OPEN(io,file=TRIM(OUTPUT_FName_b),position='append')
     ELSE
        OPEN(io,file=TRIM(OUTPUT_FName_b))
     END IF

     write(io,'(ES22.12E3)',advance='no') GetTime()
     Do i=1,NVal-1
        write(io,'(ES22.12E3)',advance='no') Val(i)
     End do
     write(io,'(ES22.12E3)') Val(NVal)
     CLOSE(io)
  END DO

  ! Sanity check
  IF (ParEnv % PEs > 1 )THEN
     CALL MPI_ALLREDUCE(SUM(CalvingFlux),ztmp,1,MPI_DOUBLE_PRECISION,MPI_SUM,ELMER_COMM_WORLD,ierr)
  ELSE
     ztmp = SUM(CalvingFlux)
  END IF
  CALL INFO(SolverName,'',Level=1)
  CALL INFO(SolverName,'--------------------------',Level=1)
  WRITE(Message,'(a,f12.4)') 'ICB CALVING [Gt/y] = ', ztmp*0.917_dp/1.0e9
  CALL INFO(SolverName,Message,Level=1)
  CALL INFO(SolverName,'--------------------------',Level=1)
  CALL INFO(SolverName,'',Level=1)

  CONTAINS

  SUBROUTINE DO_ALLOCATION(Firsttime)
    LOGICAL,INTENT(IN) :: Firsttime
    INTEGER :: M
    INTEGER :: N
    IF (.NOT.Firsttime) &
         DEALLOCATE(NodalH,NodalDHDT,NodalHf,MinH,NodalGM,NodalSMB,NodalBMB,NodalMB,rhoi,&
         LocalArea, &
         Basis,dBasisdx,&
         Val,ParVal,ValueNames,&
         NodeArea)
    N=Model % Mesh % NumberOfNodes
    M=Model % MaxElementNodes
    ALLOCATE(Basis(M),&
         dBasisdx(M,3),&
         NodalH(M),&
         NodalDHDT(M),&
         NodalHf(M),&
         MinH(M),&
         NodalGM(M),&
         NodalSMB(M),&
         NodalBMB(M),&
         NodalMB(M),&
         rhoi(M),&
         LocalArea(M),&
         Val(NVal),ParVal(NVal),ValueNames(NVal),&
         NodeArea(N),&
         & Volume(kmax), VAF(kmax), DHDTFlux(kmax), SMBFlux(kmax), BMBFlux(kmax), HMinFlux(kmax),&
         & CalvingFlux(kmax), GLFlux(kmax),GroundedArea(kmax), FloatingArea(kmax), FreeArea(kmax))
  END SUBROUTINE DO_ALLOCATION

  SUBROUTINE GET_CONSTANTS(zsea,rhow)
    IMPLICIT NONE
    REAL(KIND=dp),INTENT(OUT) :: zsea,rhow
    LOGICAL :: Found

    zsea = GetCReal( Model % Constants, 'Sea Level', Found )
    IF (.NOT.Found) CALL FATAL(SolverName,'<Sea Level> not found')
    rhow = GetCReal( Model % Constants, 'water density', Found )
    IF (.NOT.Found) CALL FATAL(SolverName,'<water density not found')
  END SUBROUTINE GET_CONSTANTS


  SUBROUTINE INIT_OUTPUT_FILE(OUTPUT_FName)
    USE GeneralUtils
    IMPLICIT NONE
    CHARACTER(LEN=MAX_NAME_LEN),INTENT(OUT) :: OUTPUT_FName

    CHARACTER(LEN=MAX_NAME_LEN) ::NamesFile,&
         OUTPUT_FName_D='TIPPACS_Scalar_OUTPUT.dat'

    CHARACTER(LEN=MAX_NAME_LEN) :: DateStr
    TYPE(ValueList_t), POINTER :: SolverParams
    LOGICAL :: Found
    INTEGER :: i

    SolverParams=>GetSolverParams(Solver)
    OUTPUT_FName = ListGetString(SolverParams,'File Name',Found)
    IF (.NOT.Found) OUTPUT_FName=TRIM(OUTPUT_FName_D)

    NamesFile = TRIM(OUTPUT_FName) // '.' // TRIM("names")

    IF ((ParEnv % PEs >1).AND.(ParEnv%MyPe.NE.0)) RETURN

    DateStr = FormatDate()

    OPEN(io,file=TRIM(NamesFile))
    WRITE(io,'(A)') 'File started at: '//TRIM(DateStr)
    WRITE(io,'(A)') ' '
    WRITE(io,'(A)') 'Elmer version: '//TRIM(GetVersion())
    WRITE(io,'(A)') 'Elmer revision: '//TRIM(GetRevision())
    WRITE(io,'(A)') 'Elmer Compilation Date: '//TRIM(GetCompilationDate())
    WRITE(io,'(A)') ' '
    WRITE(io,'(A)') 'Variables in columns of matrix:'//TRIM(OUTPUT_FName)
    WRITE(io,'(I4,": ",A)') 1,'Time'
    DO i=1,NVal
       WRITE(io,'(I4,": ",A)') i+1,TRIM(ValueNames(i))
    END DO
    CLOSE(io)
  END SUBROUTINE INIT_OUTPUT_FILE

  SUBROUTINE GET_VARIABLES()
    HVar    => VariableGet(Solver%Mesh%Variables,'h',UnfoundFatal=.TRUE.)

    DHDTVar => VariableGet(Solver%Mesh%Variables,'h velocity',UnfoundFatal=.TRUE.)

    HRVar   => VariableGet(Solver%Mesh%Variables,'h residual',UnfoundFatal=.TRUE.)

    BedVar  => VariableGet(Solver%Mesh%Variables,'bedrock',UnfoundFatal=.TRUE.)

    GMVar   => VariableGet(Solver%Mesh%Variables,'GroundedMask',UnfoundFatal=.TRUE.)

    FlowVar => VariableGet(Solver%Mesh%Variables,'SSAVelocity',UnfoundFatal=.TRUE.)
    FlowDofs = FlowVar % DOFs

    BasinVar => VariableGet( Model % Mesh % Variables, 'basins')

    IceDis => VariableGet(Model%Mesh%Variables,'IceDischarge')


    Permutation => Solver%Variable%Perm
  END SUBROUTINE GET_VARIABLES

  SUBROUTINE COMPUTE_NodeArea(NodeArea)
    IMPLICIT NONE
    REAL(KIND=dp),INTENT(OUT) :: NodeArea(:)

    TYPE(Element_t), POINTER :: Element
    TYPE(Nodes_t),SAVE :: ElementNodes
    TYPE(GaussIntegrationPoints_t) :: IntegStuff
    REAL(KIND=dp) :: U,V,W,SqrtElementMetric
    INTEGER,POINTER :: Indexes(:)
    INTEGER :: n,elem
    INTEGER :: t,i
    LOGICAL :: stat


    NodeArea=0._dp
    elem=GetNOFActive()
    Do t=1,elem

       Element => GetActiveElement(t)
       n = GetElementNOFNodes(Element)
       Indexes => Element % NodeIndexes
       CALL GetElementNodes( ElementNodes, Element )
       IntegStuff = GaussPoints( Element )
       Do i=1,IntegStuff % n
          U = IntegStuff % u(i)
          V = IntegStuff % v(i)
          W = IntegStuff % w(i)
          stat = ElementInfo(Element,ElementNodes,U,V,W,SqrtElementMetric, &
               Basis,dBasisdx )

          NodeArea(Permutation(Indexes(1:n)))=NodeArea(Permutation(Indexes(1:n)))+&
               SqrtElementMetric*IntegStuff % s(i) * Basis(1:n)

       End do
    End do
    IF (ParEnv % PEs > 1 ) CALL ParallelSumVector( Solver % Matrix, NodeArea, 0 )

  END SUBROUTINE COMPUTE_NODEAREA

  SUBROUTINE BODY_INTEGRATION(Volume,VAF,DHDTFlux,SMBFlux,BMBFlux,HMinFlux,&
       GroundedArea,FloatingArea,FreeArea)
    IMPLICIT NONE
    REAL(KIND=dp),INTENT(OUT) :: Volume(:),VAF(:),&
         DHDTFlux(:),SMBFlux(:),BMBFlux(:),HMinFlux(:),&
         GroundedArea(:),FloatingArea(:),FreeArea(:)
    REAL(KIND=dp),parameter :: tinyDP=AEPS

    TYPE(Element_t),POINTER :: Element
    TYPE(ValueList_t), POINTER :: BodyForce,Material
    TYPE(GaussIntegrationPoints_t) :: IntegStuff
    TYPE(Nodes_t),SAVE :: ElementNodes
    
    REAL(KIND=dp) :: U,V,W,SqrtElementMetric
    REAL(KIND=dp) :: Normal(3),Flow(3)
    REAL(KIND=dp) :: cellarea
    REAL(KIND=dp) :: HAtIP,SMBAtIP,BMBAtIP

    LOGICAL :: CalvingFront
    LOGICAL :: IsFloating,IceFree
    LOGICAL :: stat

    INTEGER,POINTER :: NodeIndexes(:),Indexx
    INTEGER :: t
    INTEGER :: i
    INTEGER :: n
    INTEGER :: ne

    ne=GetNOFActive()

    Volume(:)=0._dp
    VAF(:)=0._dp

    DHDTFlux(:)=0._dp
    SMBFlux(:)=0._dp
    BMBFlux(:)=0._dp
    HMinFlux(:)=0._dp

    GroundedArea(:)=0._dp
    FloatingArea(:)=0._dp
    FreeArea(:)=0._dp

    DO t = 1,ne

       Element => GetActiveElement(t)
       n = GetElementNOFNodes(Element)
       NodeIndexes => Element % NodeIndexes
       Indexx => Element % ElementIndex
       CALL GetElementNodes( ElementNodes )
       IF (.NOT.ASSOCIATED(BasinVar)) THEN
          kk = 1
       ELSE
          kk=NINT(BasinVar % Values (BasinVar % Perm (Indexx)))
       END IF
    
       BodyForce => GetBodyForce(Element)
       IF (.NOT.ASSOCIATED(BodyForce)) &
            CALL FATAL(SolverName,'No BodyForce Found')
       Material => GetMaterial(Element)
       IF (.NOT.ASSOCIATED(Material)) &
            CALL FATAL(SolverName,'No Material Found')

       NodalH(1:n) = HVar%Values(HVar%Perm(NodeIndexes(1:n)))
       NodalDHDT(1:n) = DHDTVar%Values(DHDTVar%Perm(NodeIndexes(1:n)))
       
       rhoi(1:n) = ListGetReal(Material,'SSA Mean Density',n,NodeIndexes,UnfoundFatal=.TRUE. )

       Do i=1,n
          NodalHf(i)=Max(0._dp,NodalH(i)-&
               Max(0._dp,(zsea-BedVar%Values(BedVar%Perm(NodeIndexes(i))))*rhow/rhoi(i)))
       End do

       MinH=0._dp
       MinH(1:n) = ListGetReal(Material,'Min H',n,NodeIndexes,UnfoundFatal=.TRUE. )


       ! FLOATING OR GROUNDED CELL
       NodalGM(1:n) = GMVar%Values(GMVar%Perm(NodeIndexes(1:n)))
       IsFloating=ANY(NodalGM(1:n).LT.0._dp)

       ! TOP ACCUMULATION
       NodalSMB=0._dp
       NodalSMB(1:n) = &
            ListGetReal(BodyForce,'Top Surface Accumulation', n,NodeIndexes,UnfoundFatal=.TRUE. )

       ! Bottom ACCUMULATION
       NodalBMB=0._dp
       NodalBMB(1:n) = &
            ListGetReal(BodyForce,'Bottom Surface Accumulation', n,NodeIndexes,UnfoundFatal=.TRUE. )

       ! Total ACCUMULATION
       NodalMB(1:n) = NodalSMB(1:n) + NodalBMB(1:n)

       ! CELL IS NOT ACTIVE ALL H VALUES BELOW MinH Value
       ! Fabien: Why not set condition on 1/1000(0) Hmin
       IceFree=.FALSE.
       IF (ALL((NodalH(1:n)-MinH(1:n)).LE.tinyDP).AND.ALL(NodalMB(1:n).LT.0._dp)) IceFree=.TRUE.

       ! GO TO INTEGRATION
       cellarea=0._dp
       LocalArea=0._dp

       IntegStuff = GaussPoints( Element )
       DO i=1,IntegStuff % n
          U = IntegStuff % u(i)
          V = IntegStuff % v(i)
          W = IntegStuff % w(i)

          stat = ElementInfo(Element,ElementNodes,U,V,W,SqrtElementMetric, &
               Basis,dBasisdx )
          ! cell area
          cellarea=cellarea+SqrtElementMetric*IntegStuff % s(i)
          ! the area seen by each node
          LocalArea(1:n)=LocalArea(1:n)+SqrtElementMetric*IntegStuff % s(i) * Basis(1:n)

          IF (IceFree) CYCLE

          ! Integrate H
          HAtIP=SUM(NodalH(1:n)*Basis(1:n))
          Volume(kk)=Volume(kk)+HAtIP*SqrtElementMetric*IntegStuff % s(i)

          VAF(kk)=VAF(kk)+SUM(NodalHf(1:n)*Basis(1:n))*SqrtElementMetric*IntegStuff % s(i)

          SMBAtIP=SUM(NodalSMB(1:n)*Basis(1:n))
          BMBAtIP=SUM(NodalBMB(1:n)*Basis(1:n))

          DHDTFlux(kk)=DHDTFlux(kk)+SUM(NodalDHDT(1:n)*Basis(1:n))*SqrtElementMetric*IntegStuff % s(i)
          SMBFlux(kk)=SMBFlux(kk)+SMBAtIP*SqrtElementMetric*IntegStuff % s(i)
          BMBFlux(kk)=BMBFlux(kk)+BMBAtIP*SqrtElementMetric*IntegStuff % s(i)
       END DO
       

          IF (.NOT.IceFree) THEN
             Do i=1,n
                HMinFlux(kk) = HMinFlux(kk) + &
                     HRVar%Values(HRVar%Perm(NodeIndexes(i)))*LocalArea(i)/NodeArea(Permutation(NodeIndexes(i)))
             End do
             IF (IsFloating) THEN
                FloatingArea(kk)=FloatingArea(kk)+cellarea
             ELSE
                GroundedArea(kk)=GroundedArea(kk)+cellarea
             END IF
          ELSE
             FreeArea(kk)=FreeArea(kk)+cellarea
          END IF
    END DO
  


  END SUBROUTINE BODY_INTEGRATION


  SUBROUTINE BC_INTEGRATION(CalvingFlux)
    IMPLICIT NONE
    REAL(KIND=dp),INTENT(OUT) :: CalvingFlux(:)

    TYPE(Element_t),POINTER :: Element, Parent
    TYPE(ValueList_t), POINTER :: BC
    TYPE(GaussIntegrationPoints_t) :: IntegStuff
    TYPE(Nodes_t),SAVE :: ElementNodes
    REAL(KIND=dp) :: U,V,W,SqrtElementMetric,localflux
    REAL(KIND=dp) :: Normal(3),Flow(3)

    LOGICAL :: CalvingFront
    LOGICAL :: Found
    LOGICAL :: stat

    INTEGER,POINTER :: NodeIndexes(:),Indexx
    INTEGER :: t
    INTEGER :: i,j
    INTEGER :: n

    CalvingFlux(:) = 0._dp
    localflux = 0._dp

    IF (ASSOCIATED(IceDis)) THEN 
       IceDis % Values(:) = 0.0_dp
    END IF

    DO t = 1,GetNOFBoundaryElements()
       Element => GetBoundaryElement(t)

       IF ( .NOT. ActiveBoundaryElement() ) CYCLE
       IF ( GetElementFamily() == 1 ) CYCLE

       BC => GetBC()
       IF ( .NOT. ASSOCIATED(BC) ) CYCLE
       CalvingFront=.FALSE.
       CalvingFront=ListGetLogical(BC,'Calving Front', Found)
       IF (.NOT.CalvingFront) CYCLE
       Indexx => Element % ElementIndex

       n = GetElementNOFNodes()
       NodeIndexes => Element % NodeIndexes
   
       Parent => Element % BoundaryInfo % Right
       IF ( .NOT. ASSOCIATED(Parent) )&
            Parent => Element % BoundaryInfo % Left
       
       IF ( .NOT. ASSOCIATED(Parent) ) THEN
          WRITE(Message, *)&            
          'No parent element found for boundary element no. ', n
          CALL FATAL('simpleRadiation',Message)
       END IF
       IF ( .NOT. ASSOCIATED(BasinVar) ) THEN
          kk = 1
       ELSE
          kk=NINT(BasinVar % Values (BasinVar % Perm (Parent % ElementIndex)))
       END IF
       

       CALL GetElementNodes( ElementNodes )

       NodalH(1:n) = HVar%Values(HVar%Perm(NodeIndexes(1:n)))

       IntegStuff = GaussPoints( Element )
       DO i=1,IntegStuff % n
          U = IntegStuff % u(i)
          V = IntegStuff % v(i)
          W = IntegStuff % w(i)
          stat = ElementInfo(Element,ElementNodes,U,V,W,SqrtElementMetric, &
               Basis,dBasisdx )
          Normal=0._dp
          Normal = NormalVector( Element,ElementNodes,u,v,.TRUE. )

          Flow=0._dp
          DO j=1,FlowDofs
             Flow(j) = SUM( FlowVar % Values(FlowDofs*(FlowVar % Perm(NodeIndexes(1:n)) -1)+j) * Basis(1:n) )
          END DO

          localflux = SUM(NodalH(1:n)*Basis(1:n))*SUM(Normal * Flow)*SqrtElementMetric*IntegStuff % s(i)
         
          IF (ASSOCIATED(IceDis)) THEN 
            IceDis % Values( IceDis % Perm (Parent % ElementIndex))=IceDis % Values( IceDis % Perm (Parent % ElementIndex)) + localflux
          END IF
          
          CalvingFlux(kk)=CalvingFlux(kk)+ localflux
       END DO
    END DO
  END SUBROUTINE BC_INTEGRATION


  SUBROUTINE COMPUTE_GL_FLUX( GLFlux  )
    IMPLICIT NONE
    REAL(KIND=DP),INTENT(OUT) :: GLFlux(:)

    TYPE(Mesh_t),POINTER :: Mesh
    TYPE(Element_t),DIMENSION(:),POINTER :: Edges
    TYPE(Element_t),POINTER :: Edge,Parent


    REAL(KIND=DP),ALLOCATABLE,SAVE :: LocalGM(:),LocalFlow(:,:),LocalH(:)

    INTEGER, POINTER :: NodeIndexes(:),Indexx
    INTEGER ::  Ne 
    INTEGER :: n
    INTEGER :: i,j
    INTEGER :: M

    LOGICAL, SAVE :: Firsttime=.TRUE.


    IF (Firsttime) THEN
       M=Model % MaxElementNodes
       ALLOCATE(LocalGM(M),LocalFlow(3,M),LocalH(M))
       Firsttime=.FALSE.
    END IF

    Mesh => GetMesh()


    CALL FindMeshEdges(Mesh,.FALSE.) 

    Edges => Mesh % Edges
    Ne = Mesh % NumberOfEdges

    GLFlux(:)=0._dp

    DO i=1,Ne
       Edge => Edges(i)
       n=Edge % TYPE % NumberOfNodes

       NodeIndexes(1:n) => Edge % NodeIndexes(1:n)

       LocalGM(1:n)=GMVar % Values ( GMVar % Perm ( NodeIndexes(1:n) ) )
       ! Edge is GL if all GM=0
       IF ( ANY( abs(LocalGM(1:n)) .GT. AEPS ) ) CYCLE

       DO j=1,DIM
          LocalFlow(j,1:n) = FlowVar % Values ( DIM*(FlowVar % Perm ( NodeIndexes(1:n) ) - 1) + j )
       END DO
       LocalH(1:n) = HVar % Values ( HVar % Perm ( NodeIndexes(1:n) ) )

       Parent => Edge % BoundaryInfo % Right
       CALL AddLocalFlux(GLFlux,LocalFlow,LocalH,Edge,Parent,Mesh)
       Parent => Edge % BoundaryInfo % Left 
       CALL AddLocalFlux(GLFlux,LocalFlow,LocalH,Edge,Parent,Mesh)
    END DO

  END SUBROUTINE COMPUTE_GL_FLUX

  SUBROUTINE AddLocalFlux(Flux,LocalFlow,LocalH,Edge,Parent,Mesh) 
    IMPLICIT NONE
    TYPE(Element_t),POINTER :: Edge,Parent
    TYPE(Mesh_t), POINTER :: Mesh
    REAL(KIND=dp),INTENT(INOUT) :: Flux(:)
    REAL(KIND=dp),INTENT(IN) :: LocalFlow(:,:),LocalH(:)

    TYPE(Nodes_t),SAVE :: EdgeNodes
    TYPE(GaussIntegrationPoints_t) :: IntegStuff
    
    REAL(KIND=dp) :: U,V,W,SqrtElementMetric
    REAL(KIND=dp),ALLOCATABLE,SAVE :: Basis(:), dBasisdx(:,:)

    REAL(KIND=dp),DIMENSION(3) :: dx, Normal,Flow
    REAL(KIND=dp) :: h

    INTEGER :: i,j
    INTEGER :: n,np 
    INTEGER :: M

    LOGICAL :: stat
    LOGICAL,SAVE :: FirstVisit=.TRUE.

    IF (FirstVisit) THEN
       M=Model % MaxElementNodes
       ALLOCATE(Basis(M),dBasisdx(M,3))
       FirstVisit=.FALSE.
    END IF

    ! Parent not associated
    IF (.NOT.ASSOCIATED(Parent)) RETURN
    ! Parent is halo element
    IF( Parent % PartIndex /= ParEnv % MyPe ) RETURN
    !
    n = Edge % TYPE % NumberOfNodes
    np = Parent % TYPE % NumberOfNodes
    ! Parent is Grounded if ALL GM>=0
    IF ( ALL( GMVar % Values( GMVar % Perm( Parent % NodeIndexes(1:np) ) ) .GT. -AEPS ) ) RETURN
    ! a vector from the center of the edge to the center of the parent to check that normal points toward parent (floating)
    dx = ElementCenter(Mesh,Parent) - ElementCenter(Mesh,Edge)

    CALL GetElementNodes(EdgeNodes, Edge)
    IF (.NOT.ASSOCIATED(BasinVar)) THEN
       kk = 1
    ELSE
       kk=NINT(BasinVar % Values (BasinVar % Perm (Parent % ElementIndex)))
    END IF
    IntegStuff = GaussPoints( Edge ) 
    DO i=1,IntegStuff % n
       U = IntegStuff % u(i)
       V = IntegStuff % v(i)
       W = IntegStuff % w(i)
       stat = ElementInfo( Edge,EdgeNodes,U,V,W,SqrtElementMetric, &
            Basis,dBasisdx )

       DO j=1,DIM
          Flow(j) = SUM(LocalFlow(j,1:n)*Basis(1:n))
       END DO
       h = SUM(LocalH(1:n)*Basis(1:n))

       Normal = NormalVector( Edge,EdgeNodes,U,V,.FALSE. )

       IF ( SUM(dx(1:DIM)*Normal(1:DIM)).LT.0._dp ) Normal=-Normal

       Flux(kk) = Flux(kk) + SqrtElementMetric * IntegStuff % s(i) * h * SUM(Normal(1:DIM)*Flow(1:DIM))

    END DO

  END SUBROUTINE AddLocalFlux
  !
  !      
  FUNCTION ElementCenter(Mesh,Element) RESULT(xc)
    IMPLICIT NONE
    TYPE(Mesh_t), POINTER :: Mesh
    TYPE(Element_t),POINTER :: Element
    REAL(KIND=dp),DIMENSION(3) :: xc
    INTEGER :: n

    n = Element % TYPE % NumberOfNodes
    xc=0._dp
    SELECT CASE( Element % TYPE % ElementCode / 100 )
    CASE(2,4,8)
       xc(1) = InterpolateInElement( Element, Mesh % Nodes % x(Element % NodeIndexes(1:n)), 0.0d0, 0.0d0, 0.0d0 )
       xc(2) = InterpolateInElement( Element, Mesh % Nodes % y(Element % NodeIndexes(1:n)), 0.0d0, 0.0d0, 0.0d0 )
    CASE(3)
       xc(1) = InterpolateInElement( Element, Mesh % Nodes % x(Element % NodeIndexes(1:n)), 1.0d0/3, 1.0d0/3, 0.0d0 )
       xc(2) = InterpolateInElement( Element, Mesh % Nodes % y(Element % NodeIndexes(1:n)), 1.0d0/3, 1.0d0/3, 0.0d0 )
    CASE DEFAULT
       CALL FATAL(SolverName,'Element type not supported')
    END SELECT

  END FUNCTION ElementCenter
END SUBROUTINE INITMIP_Scalar_OUTPUT

