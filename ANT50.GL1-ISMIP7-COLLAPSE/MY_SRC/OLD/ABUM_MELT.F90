
       FUNCTION ABUM_MELT(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       IF (VarIn.GT.-0.5) THEN
          VarOut=0._dp
       ELSE
          VarOut=-400.0_dp
       END IF
       End FUNCTION ABUM_MELT

       FUNCTION ABUM_MELT2(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut
       TYPE(Element_t), POINTER :: Element
       REAL(KIND=dp), POINTER :: GMask(:)
       INTEGER, POINTER :: GMaskPerm(:)
       TYPE(variable_t), POINTER :: GMVar
       
       GMVar => VariableGet( Model % Mesh % Variables,'GroundedMask',UnFoundFatal=.TRUE.)
       GMask => GMVar % Values
       GMaskPerm => GMVar % Perm

       Element => Model % CurrentElement
       IF (ALL(GMask(GMaskPerm(Element % NodeIndexes)).LT.-0.5)) THEN
          VarOut = -400.0_dp
       ELSE
          VarOut=0._dp
       END IF

       End FUNCTION ABUM_MELT2
