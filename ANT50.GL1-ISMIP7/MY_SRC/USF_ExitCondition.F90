!***************************************************************************
!#  A USF that generate a positive Exit Condition when a given threshold
!   on the velocity or thickness norm is exceeded.
!   
!   This Condition is evaluated at the end of each time step
!
!   Usage: In section Simulation
!      Exit Condition = Variable Time
!          Real Procedure "ExitCondition" "ExitCondition"
!***************************************************************************
      FUNCTION ExitCondition(Model,nodenumber,VarIn) RESULT(VarOut)
      USE DefUtils
      implicit none
      !-----------------
      TYPE(Model_t) :: Model
      INTEGER :: nodenumber
      REAL(kind=dp) :: VarIn,VarOut

      TYPE(Variable_t), POINTER :: SSA,H
      REAL(KIND=dp) :: SSANorm,HNorm
      REAL(KIND=dp),Parameter :: SSATreshold=1.0d04,HTreshold=1.0d05

      SSA => VariableGet(Model%Mesh%Variables,"ssavelocity",UnFoundFatal=.TRUE.)
      SSANorm = SSA % Norm
      H => VariableGet(Model%Mesh%Variables,"H",UnFoundFatal=.TRUE.)
      HNorm = H % Norm

      IF ((SSANorm.GT.SSATreshold).OR.(HNorm.GT.HTreshold)) THEN
        CALL WARN("ExitCondition","***********************************")
        WRITE( Message, '(a,g15.8,a,g15.8)') "Velocity norm",SSANorm,&
                                           "H norm",HNorm
        CALL WARN("ExitCondition", Message)
        CALL WARN("ExitCondition", "Exiting .....")
        CALL WARN("ExitCondition","***********************************")
        VarOut = +1._dp
      ELSE
        VarOut = -1._dp
      ENDIF
      End FUNCTION ExitCondition
