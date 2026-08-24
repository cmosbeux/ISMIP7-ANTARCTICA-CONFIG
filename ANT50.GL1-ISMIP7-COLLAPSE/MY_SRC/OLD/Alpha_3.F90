       FUNCTION Alpha_3(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(2) !,ux,uy
       REAL(kind=dp) :: VarOut

       REAL(kind=dp) :: ub
       REAL(kind=dp) :: taub,COMPUTE_SSA_NODAL_Bdrag
       REAL(kind=dp) :: C3
       REAL(kind=dp),parameter :: n=3._dp
       REAL(kind=dp),parameter :: CMin=1.0d-06


       ub=sqrt(SUM(VarIn(1:2)*VarIn(1:2)))
       taub=COMPUTE_SSA_NODAL_Bdrag(nodenumber)

       C3=max(CMin,taub/(ub+AEPS)**(1._dp/n))
       VarOut=Log10(C3)

       End FUNCTION Alpha_3
