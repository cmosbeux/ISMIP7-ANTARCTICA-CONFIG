SUBROUTINE ComputedSMBSolver( Model, Solver, dt, TransientSimulation )
!------------------------------------------------------------------------------
  USE DefUtils

  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Solver_t), TARGET :: Solver
  TYPE(Model_t) :: Model

  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation

!------------------------------------------------------------------------------
! Local variables
!------------------------------------------------------------------------------
  TYPE(ValueList_t), POINTER :: SolverParams
  TYPE(Element_t),POINTER :: Element
  TYPE(GaussIntegrationPoints_t) :: IP
  TYPE(Nodes_t),SAVE :: Nodes

  TYPE(Variable_t), POINTER :: dSMBVar,dSMBdzVar,ZsVar,ZsRefVar

  REAL(KIND=dp), ALLOCATABLE,SAVE :: Basis(:),NodalZs(:),NodalZsRef(:)
  REAL(KIND=dp) :: detJ,s,dzAtIP
  REAL(KIND=dp) :: Earea,Edz,EdSMBdz

  INTEGER :: kk,EIndex
  INTEGER :: n
  INTEGER :: t,p
  INTEGER :: NoFActive

  LOGICAL, SAVE :: FirstTime=.TRUE.
  LOGICAL :: GotIt,stat

  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='ComputedSMBSolver'

  IF (FirstTime) THEN
    n = MAX(Solver%Mesh % MaxElementNodes,Solver%Mesh % MaxElementDOFs)
    ALLOCATE(Basis(n),NodalZs(n),NodalZsRef(n))
    FirstTime=.False.
  END IF

  SolverParams => GetSolverParams()

  ! Get Required variables
  ! 1. Zs;ZsRef
  ZsVar => VariableGet(Solver% Mesh % Variables,'Zs',UnfoundFatal=.True.)
  ZsRefVar => VariableGet(Solver% Mesh % Variables,'ZsRef',UnfoundFatal=.True.)

  ! 2. dSMBdz
  dSMBdzVar => VariableGet(Solver%Mesh%Variables,'dSMBdz',UnFoundFatal=.TRUE.)
  IF (dSMBdzVar % Type .NE. Variable_on_elements) &
     CALL FATAL(TRIM(SolverName),'Variable dSMBdz should be on elements')

  ! 3. dSMB
  dSMBVar => VariableGet(Solver%Mesh%Variables,'dSMB',UnFoundFatal=.TRUE.)
  IF (dSMBVar % Type .NE. Variable_on_elements) &
     CALL FATAL(TRIM(SolverName),'Variable dSMB should be on elements')
  dSMBVar % Values = 0._dp


   NoFActive = getnofactive()

   DO t = 1,NoFActive
      element => GetActiveElement(t)
      EIndex = element % elementIndex

      kk = dSMBdzVar % Perm (EIndex)
      EdSMBdz=0._dp
      IF (kk.GT.0) EdSMBdz=dSMBdzVar % Values (kk)

      CALL GetLocalSolution(NodalZs,UElement=Element,UVariable=ZsVar)
      CALL GetLocalSolution(NodalZsRef,UElement=Element,UVariable=ZsRefVar)

      n  = GetElementNOFNodes(Element)

      CALL GetElementNodes(Nodes,Element)
      IP = GaussPoints( Element )

      Earea=0._dp
      Edz=0._dp
      DO p = 1, IP % n
           stat = ElementInfo( Element, Nodes, IP % U(p), IP % V(p), &
              IP % W(p), detJ, Basis)
           s = detJ * IP % S(p)

           dzAtIP=SUM((NodalZs(1:n)-NodalZsRef(1:n))*Basis(1:n))

           Earea=Earea+s
           Edz=Edz+dzAtIP*s
      END DO

      kk = dSMBVar % Perm(EIndex)
      IF(kk.GT.0) dSMBVar%Values(kk) = EdSMBdz*Edz/Earea

   END DO

!------------------------------------------------------------------------------
END SUBROUTINE ComputedSMBSolver
!------------------------------------------------------------------------------
                                                                                                                                                                   102,1         Bot
