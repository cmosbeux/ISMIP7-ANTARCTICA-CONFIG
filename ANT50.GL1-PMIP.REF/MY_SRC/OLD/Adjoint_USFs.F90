!#######################################################################
!# A collection of user functions to do variable change in inverse
!methods 
!#######################################################################
!# Compute VarOut=10^VarIn
       FUNCTION TenPowerA(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       VarOut = 10._dp**(VarIn)

       End FUNCTION TenPowerA
       FUNCTION TenPowerA_Grounded(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(2),VarOut

       IF (VarIn(2).LT.-0.5) THEN
          !VarOut = 10._dp**(-32.0)
          VarOut = 0.0
       ELSE
          VarOut = 10._dp**(VarIn(1))
       END IF

       End FUNCTION TenPowerA_Grounded
!# Compute DJDA from DJDB if B=10^A: DJDA=DJDB*ln(10)*10^A
!# Compute DJDA from DJDB if B=10^A: DJDA=DJDB*ln(10)*10^A
!# DJDB=VarIn(1)
!# A=VarIn(2)
       FUNCTION Derivative_TenPowerA(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(2),VarOut

       VarOut = VarIn(1)*(10.0**(VarIn(2)))*log(10.0)

       End FUNCTION Derivative_TenPowerA
       FUNCTION Derivative_TenPowerA_Grounded(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(3),VarOut

       IF (VarIn(3).LT.-0.5) THEN
          VarOut = 0._dp
       ELSE
          VarOut = VarIn(1)*(10.0**(VarIn(2)))*log(10.0)
       ENDIF
       End FUNCTION Derivative_TenPowerA_Grounded
!# Compute VarOut=VarIn*VarIn
       FUNCTION Asquare(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       VarOut = VarIn*VarIn
       END FUNCTION Asquare
!# Compute DJDA from DJDB if B=A^2: DJDA=DJDB*2A
!# DJDB=VarIn(1)
!# A=VarIn(2)
       FUNCTION Derivative_Asquare(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(2),VarOut

       VarOut = 2.0*VarIn(1)*VarIn(2)

       End FUNCTION Derivative_Asquare
!# Compute VarOut=sqrt(VarIn)
       FUNCTION Asqrt(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       VarOut = sqrt(VarIn)
       END FUNCTION Asqrt
