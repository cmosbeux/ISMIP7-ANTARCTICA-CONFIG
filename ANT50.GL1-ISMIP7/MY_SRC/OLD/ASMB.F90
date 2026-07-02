      FUNCTION ASMB(Model,nodenumber,VarIn)  RESULT(VarOut)
       USE Types
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(3) !Time,smb,asmb
       REAL(kind=dp) :: VarOut
       !-----------------
       INTEGER :: pert

       pert=MAX(0,floor(VarIn(1)))

       If (Varin(1).LT.40._dp) THEN
          VarOut=VarIn(2)+ (pert/40.0)*VarIn(3)
       Else
          VarOut=VarIn(2)+VarIn(3)
       End if

      END FUNCTION ASMB

