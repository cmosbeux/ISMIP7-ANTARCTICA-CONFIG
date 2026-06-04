!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!  Pb echouage 
!
!    to be compiled with the associated geometry function 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FUNCTION WaterPressure ( Model, nodenumber, zb) RESULT(Pwater)
  USE types
  USE CoordinateSystems
  USE SolverUtils
  USE ElementDescription
  USE DefUtils
  IMPLICIT NONE
  TYPE(Model_t) :: Model
  TYPE(Solver_t), TARGET :: Solver
  INTEGER :: nodenumber
 
  TYPE(ValueList_t) , POINTER :: Constants

  REAL(KIND=dp) :: rhow, g, zsea, zb, Pwater          
  LOGICAL :: FirstTime=.TRUE., Found

  CHARACTER(LEN=MAX_NAME_LEN) :: USFName='USF_WaterPressure'

  SAVE FirstTime, rhow, g, zsea

   IF (FirstTime) THEN
      FirstTime = .False.

      zsea = GetCReal( Model % Constants, 'Sea Level', Found )
      If (.NOT.Found) THEN
         WRITE(Message,'(A)') 'Constant >Sea Level< not found. &
            &Setting to 0.0'
         CALL INFO(USFName, Message, level=3)
         zsea = 0._dp
       End if

       rhow = GetCReal( Model % Constants, 'water density', Found )
       If (.NOT.Found) THEN
          WRITE(Message,'(A)') 'Constant Water Density not found. &
             &Setting to 1.03225e-18'
          CALL INFO(USFName, Message, level=3)
          rhow = 1.03225d-18
        END IF

        g = GetCReal ( Model % Constants, 'Gravity', Found )
        If (.NOT.Found) THEN
           WRITE(Message,'(A)') 'Constant >Gravity< not found. &
             &Setting to -9.746289e15'
           CALL INFO(USFName, Message, level=3)
           g = -9.746289e15
        End if
    END IF
 
   Pwater = MAX(0.0_dp, rhow * abs(g)*(zsea-zb))

END FUNCTION WaterPressure



