      FUNCTION ABMB(Model,nodenumber,VarIn)  RESULT(VarOut)
       USE Types
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(4) !Time,smb,asmb,groundedmask
       REAL(kind=dp) :: VarOut
       !-----------------
       INTEGER :: pert

       IF (VarIn(4).GT.-0.5)  THEN
          VarOut=0._dp
       ELSE

         pert=MAX(0,floor(VarIn(1)))

         If (Varin(1).LT.40._dp) THEN
            VarOut=VarIn(2)+ (pert/40.0)*VarIn(3)
         Else
            VarOut=VarIn(2)+VarIn(3)
         End if
       END IF

      VarOut=-VarOut

      END FUNCTION ABMB

