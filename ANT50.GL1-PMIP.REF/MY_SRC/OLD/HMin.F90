       FUNCTION HMin(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut
       REAL(kind=dp) :: Hc
       LOGICAL :: Found

       Hc = GetCReal( Model % Constants, 'HMin Critical Thickness', Found )
       IF (.NOT.Found) &
          CALL FATAL('HMin','<HMin Critical Thickness> not found')

       VarOut = MAX(VarIn,Hc)

       End FUNCTION HMin
