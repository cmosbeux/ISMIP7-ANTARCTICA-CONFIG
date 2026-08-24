!! Compute initial Friction value as C=rho*g*(zs-zb)*alpha/||u||^m
      FUNCTION Log10CIni(Model,nodenumber,VarIn) RESULT(VarOut)

       USE DefUtils

       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn(6) !GroundedMask,h,ds/dx,ds/dy,ux,uy
       REAL(kind=dp) :: VarOut

       TYPE(ValueList_t), POINTER :: Material,BodyForce
       REAL(kind=dp) :: rho,g,H,alpha,u,fm
       REAL(kind=dp) :: C
       REAL(kind=dp),parameter :: CMin=1.0d-6,CMax=1.0_dp,CNoVal=1.0d-1
       REAL(kind=dp),parameter :: HMin=1.0d-1,UMin=1.0_dp
       LOGICAL :: Found
       CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='CInit'
       CHARACTER(LEN=MAX_NAME_LEN) :: Friction


       Material => GetMaterial()
       IF (.NOT.ASSOCIATED(Material)) CALL FATAL(SolverName,&
              'Material not ASSOCIATED')
       BodyForce => GetBodyForce()
       IF (.NOT.ASSOCIATED(BodyForce)) CALL FATAL(SolverName,&
              'BodyForce not ASSOCIATED')

     ! get density
       rho=ListGetRealAtNode(Material, 'SSA Mean Density',nodenumber,Found)
       IF (.NOT.Found) &
           CALL FATAL(SolverName,&
                'Could not find Material prop.  >SSA Mean Density<')

     !get gravity
       g=ListGetRealAtNode(BodyForce,'Flow BodyForce 3',nodenumber,Found)
       IF (.NOT.Found) &
           CALL FATAL(SolverName,&
                'Could not find Body Force >Flow BodyForce 3<')

     IF (VarIn(1).LT.-0.5) THEN
        C=CMin
     ELSE

     ! H=zs-zb
       H=VarIn(2)

     !slope
       alpha=sqrt(VarIn(3)*VarIn(3)+VarIn(4)*VarIn(4))

     ! velocity
       u=sqrt(VarIn(5)*VarIn(5)+VarIn(6)*VarIn(6))

     ! get friction exponent
        Friction = GetString(Material, 'SSA Friction Law', Found)
        IF (.NOT.Found) &
           CALL FATAL(SolverName,&
                'Could not find Material keyword >SSA Friction Law<')

      SELECT CASE(Friction)
       CASE('linear')
           fm = 1.0_dp
       CASE('weertman')
           fm = ListGetConstReal( Material, 'SSA Friction Exponent', Found )
           IF (.NOT.Found) &
               CALL FATAL(SolverName,&
                'Could not find Material prop. >SSA Friction Exponent<')
       CASE DEFAULT
         CALL FATAL(SolverName,'Friction should be linear or Weertman')
      END SELECT

      ! Compute C
      IF ((H.LT.Hmin).OR.(u.LT.Umin)) THEN
          C=CNoVal
      ELSE
          C=abs(rho*g)*H*alpha/u**fm
      END IF

      ENDIF

       VarOut=Log10(min(max(CMin,C),CMax))

       End FUNCTION Log10CIni

