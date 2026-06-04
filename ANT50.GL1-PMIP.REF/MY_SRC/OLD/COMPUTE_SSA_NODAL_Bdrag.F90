      FUNCTION COMPUTE_SSA_NODAL_Bdrag(node) RESULT(Bdrag)
      USE DefUtils
      USE ModelDescription
      IMPLICIT NONE
      
      INTEGER,INTENT(IN) :: node
      REAL(dp) :: Bdrag

      INTEGER :: k,i
      INTEGER :: ndim
      TYPE(ValueList_t), POINTER ::   Material
      TYPE(Variable_t), POINTER :: NSol,GM,SSA
      CHARACTER(LEN=MAX_NAME_LEN) :: Friction
      REAL(dp) ::beta,fm,LinVelo,MinN
      REAL(dp) :: PostPeak,fC,fT,fN
      REAL(dp) :: alpha,fb
      REAL(dp) :: SlipW,SlipC
      REAL(dp) :: Slip
      REAL(dp) :: unorm,ub
      INTEGER :: iFriction
      LOGICAL :: Found

      Bdrag=0._dp

      GM => VariableGet(CurrentModel % Mesh % Variables, &
                     'groundedmask',UnFoundFatal=.TRUE. )

      IF (GM%Values(GM%Perm(node)).LT.0._dp) RETURN


      Do k=1,CurrentModel % NumberOFMaterials
          Material => CurrentModel % Materials(k) % Values
          Friction = ListGetString(Material, 'SSA Friction Law', Found)
          IF (Found) EXIT
      End Do
      
      SELECT CASE(Friction)
       CASE('linear')
         iFriction = 1
         fm = 1.0_dp
       CASE('weertman')
         iFriction = 2
       CASE('coulomb')
         iFriction = 3
       CASE('tsai')
         iFriction = 4
       CASE DEFAULT
         CALL FATAL('Compute Brag',&
              'Friction should be linear, Weertman or Coulomb')
      END SELECT

      beta=ListGetRealAtNode(Material,'SSA Friction Parameter',node,UnFoundFatal=.TRUE.)
      IF (iFriction > 1) THEN
         fm = ListGetConstReal( Material, 'SSA Friction Exponent', UnFoundFatal=.TRUE.)
         LinVelo=ListGetRealAtNode(Material, &
                  'SSA Friction Linear Velocity',node,UnFoundFatal=.TRUE.)
      ENDIF
      IF (iFriction > 2) THEN
         MinN = ListGetConstReal( Material, 'SSA Min Effective Pressure',UnFoundFatal=.TRUE.)
         NSol => VariableGet(CurrentModel % Mesh % Variables, &
                     'Effective Pressure',UnFoundFatal=.TRUE. )
         fN = MAX(NSol%Values(NSol%Perm(node)) , MinN)
      END IF
      IF (iFriction == 3) THEN
        PostPeak = ListGetConstReal( Material, 'SSA Friction Post-Peak', UnFoundFatal=.TRUE. )
        fC = ListGetRealAtNode(Material, &
                 'SSA Friction Maximum Value', node,UnFoundFatal=.TRUE.)
      END IF
      IF (iFriction == 4) THEN
       fT = ListGetRealAtNode(Material,&
           'SSA Tsai Coulomb Friction Parameter', node,UnFoundFatal=.TRUE.)
      END IF

      
      SSA => VariableGet(CurrentModel % Mesh % Variables, &
                     'ssavelocity',UnFoundFatal=.TRUE. )
      ndim=SSA%DOfs
      unorm=0._dp
      Do i=1,ndim
        unorm=unorm+SSA%Values(ndim*(SSA%Perm(node)-1)+i)*SSA%Values(ndim*(SSA%Perm(node)-1)+i)
      End do
      unorm=sqrt(unorm)

      ub=MAX(unorm,LinVelo)

      IF (iFriction==1) THEN
        Slip = beta
      ELSE IF (iFriction==2) THEN
        Slip = beta * ub**(fm-1.0_dp)
      ELSE IF (iFriction==3) THEN
        IF (PostPeak.NE.1.0_dp) THEN
          alpha = (PostPeak-1.0_dp)**(PostPeak-1.0_dp) / PostPeak**PostPeak
        ELSE
         alpha = 1.0_dp
        END IF
        fB = alpha * (beta / (fC*fN))**(PostPeak/fm)
        Slip = beta * ub**(fm-1.0_dp) / (1.0_dp + fB * ub**PostPeak)**fm
      ELSE IF (iFriction==4) THEN
        SlipW = beta * ub**(fm-1.0_dp)
        SlipC = fT * fN * ub**(-1.0_dp)
        IF (SlipW .LT.  SlipC) THEN
          Slip = SlipW
        ELSE
          Slip = SlipC
        END IF
      END IF

      Bdrag = Slip * unorm

      END FUNCTION COMPUTE_SSA_NODAL_Bdrag
