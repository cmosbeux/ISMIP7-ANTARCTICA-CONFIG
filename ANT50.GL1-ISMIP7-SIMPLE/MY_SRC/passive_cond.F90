       FUNCTION passive_cond(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       TYPE(ValueList_t),POINTER :: BodyForce,Material
       TYPE(Variable_t),POINTER :: HVar
       TYPE(Element_t), POINTER :: CurElement
       REAL(KIND=dp), PARAMETER :: EPS=EPSILON(1.0)
       REAL(KIND=dp), ALLOCATABLE,SAVE :: MinH(:),NodalH(:)
       INTEGER :: n
       LOGICAL,SAVE :: FirstTime=.True.
       LOGICAL :: GotIt

       IF (FirstTime) THEN
         n=Model % MaxElementNodes
         Allocate(MinH(n),NodalH(n))
         FirstTime=.False.
       END IF
 
       CurElement => GetCurrentElement()
       n  = GetElementNOFNodes(CurElement)

       BodyForce => GetBodyForce(CurElement)
       Material => GetMaterial(CurElement)
      
       ! Get Ice thickness
       HVar => VariableGet( Model%Mesh % Variables,'H',UnfoundFatal=.True.)
       CALL GetLocalSolution(NodalH,UElement=CurElement,UVariable=HVar)

       MinH = ListGetConstReal(BodyForce,'H Lower Limit', Gotit)
       IF (.NOT.Gotit) &
         MinH = ListGetConstReal(Material,'Min H', Gotit)
       IF (.NOT.GotIt) &
         CALL FATAL("passive_cond","Limit for H not found...")


       IF (ALL((NodalH(1:n)-EPS).LT.MinH(1:n))) THEN
        VarOut=+1._dp
       ELSE
        VarOut=-1.0_dp
      END IF

       End FUNCTION passive_cond


FUNCTION passive_fracture_elem(Model,nodenumber,VarIn) RESULT(VarOut)
      USE DefUtils
      IMPLICIT NONE

      TYPE(Model_t) :: Model
      INTEGER :: nodenumber
      REAL(KIND=dp) :: VarIn, VarOut

      TYPE(Variable_t), POINTER :: MaskVar
      TYPE(Element_t), POINTER :: CurElement
      INTEGER :: eIndex, k
      REAL(KIND=dp) :: maskValue

      CurElement => GetCurrentElement()
      eIndex = CurElement % ElementIndex

      MaskVar => VariableGet(Model % Mesh % Variables, 'Fracture_Mask', &
           UnfoundFatal = .TRUE.)

      IF (MaskVar % TYPE .NE. Variable_on_elements) THEN
         CALL FATAL('passive_fracture_elem', &
              'Fracture_Mask must be an elemental variable')
      END IF

      IF (.NOT. ASSOCIATED(MaskVar % Perm)) THEN
         CALL FATAL('passive_fracture_elem', &
              'Fracture_Mask has no valid permutation')
      END IF

      k = MaskVar % Perm(eIndex)
      IF (k <= 0) THEN
         VarOut = -1.0_dp
         RETURN
      END IF

      maskValue = MaskVar % Values(k)

      IF (maskValue > 0.0_dp) THEN
         VarOut = -1.0_dp
      ELSE
         VarOut = 1.0_dp
      END IF

  END FUNCTION passive_fracture_elem


FUNCTION passive_grounded_fracture(Model,nodenumber,VarIn) RESULT(VarOut)
    USE DefUtils
    IMPLICIT NONE

    TYPE(Model_t) :: Model
    INTEGER :: nodenumber
    REAL(KIND=dp) :: VarIn, VarOut

    TYPE(Variable_t), POINTER :: MaskVar, GroundedVar
    TYPE(Element_t), POINTER :: CurElement
    REAL(KIND=dp), PARAMETER :: EPS=EPSILON(1.0_dp)
    REAL(KIND=dp), ALLOCATABLE, SAVE :: NodalGrounded(:)
    REAL(KIND=dp) :: maskValue
    INTEGER :: eIndex, k, n
    LOGICAL, SAVE :: FirstTime=.True.

    IF (FirstTime) THEN
      n = Model % MaxElementNodes
      ALLOCATE(NodalGrounded(n))
      FirstTime = .False.
    END IF

    CurElement => GetCurrentElement()
    eIndex = CurElement % ElementIndex
    n = GetElementNOFNodes(CurElement)

    MaskVar => VariableGet(Model % Mesh % Variables, 'Fracture_Mask', &
       UnfoundFatal = .TRUE.)
    IF (MaskVar % TYPE .NE. Variable_on_elements) THEN
       CALL FATAL('passive_grounded_fracture', &
          'Fracture_Mask must be an elemental variable')
    END IF
    IF (.NOT. ASSOCIATED(MaskVar % Perm)) THEN
       CALL FATAL('passive_grounded_fracture', &
          'Fracture_Mask has no valid permutation')
    END IF

    GroundedVar => VariableGet(Model % Mesh % Variables, 'GroundedMask', &
       UnfoundFatal = .TRUE.)
    CALL GetLocalSolution(NodalGrounded, UElement=CurElement, &
       UVariable=GroundedVar)

    k = MaskVar % Perm(eIndex)
    IF (k <= 0) THEN
       VarOut = -1.0_dp
       RETURN
    END IF

    maskValue = MaskVar % Values(k)

    IF ((maskValue .GT. 0.0_dp) .AND. (ALL(ABS(NodalGrounded(1:n) + 1.0_dp) .LE. EPS))) THEN
       VarOut = -1.0_dp
    ELSE
       VarOut = 1.0_dp
    END IF

END FUNCTION passive_grounded_fracture