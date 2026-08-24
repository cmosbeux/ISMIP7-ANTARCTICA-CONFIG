       FUNCTION ABMB_To_BM(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(3) !GroundedMask,Zb,ABMB
       REAL(kind=dp) :: VarOut
       REAL(kind=dp) :: sealevel
       LOGICAL :: Found

       IF (Varin(1).GT.0.5) THEN
          VarOut=0._dp
       ELSE
          ! IF grounding line is above sealevel, melt=0
          sealevel = GetCReal( Model % Constants, 'Sea Level', Found)
          IF (.NOT.Found) &
             CALL FATAL('ABMB_To_BM','<Sea Level> not found')
          IF (VarIn(2).GT.sealevel) THEN
             VarOut=0._dp
          ELSE
             VarOut=VarIn(3)
          ENDIF
       END IF
       
       End FUNCTION ABMB_To_BM
