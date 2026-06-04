!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Compute the viscosity as Visc=prefactor^2 * Mu
! .sif usage: SSA Mean Viscosity = Variable "prefactor", "Mu"
! where prefactor is a dimensionless prefactor used to scale the initial
!  viscosity field "Mu"
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       FUNCTION SSAViscosity(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(2)
       REAL(kind=dp) :: VarOut
      
       REAL(kind=dp) :: prefactor,mu
     
         prefactor=VarIn(1)
         mu=VarIn(2)
         
         VarOut=prefactor*prefactor*mu

       END
