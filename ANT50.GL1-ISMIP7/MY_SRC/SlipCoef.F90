FUNCTION Calcul_Slc(model, nodenumber, VarIn) RESULT(VarOut)
   USE DefUtils
   IMPLICIT NONE 
   TYPE(Model_t) :: model
   INTEGER :: nodenumber
   REAL (KIND=dp) :: VarIn(2) ! slc0, Haf
   REAL (KIND=dp) :: VarOut   ! slc

   TYPE(ValueList_t), POINTER :: material
   REAL(kind=dp) :: lda    ! ratio Haf/Haf_treshold (max set to=1)
   REAL(kind=dp) :: h_af   ! Haf
   REAL(kind=dp) :: hth    ! Haf treshold
   REAL(kind=dp) :: slc0   ! non modified slip coeficient
 
   ! inquire SSA friction exponent from Material properties
   material => GetMaterial()
   IF (.NOT. ASSOCIATED(material)) CALL Fatal('SlipCoef_USF', "No material found?")

   ! get needed variable
   hth  = ListGetConstReal( Material, 'SSA Friction Threshold Height',UnFoundFatal=.TRUE.) 

   ! non modified slip coneficient (slc0)
   slc0 = VarIn(1)

   ! heigh above flotation (h_af)
   h_af = VarIn(2)

   ! compute scale scale factor  
   !     0 on floating part
   !     1 where above treshold
   ! [0-1] where between free floating and treshold

   ! general case
   lda=h_af/hth

   ! where floating => 0
   IF ( lda .LE. 0.0 ) lda=+0.0

   ! haf superior to h_threshold => 1
   IF ( h_af .GE. hth ) lda=+1.0

   ! output : slc corrected by Haf (ie close to GL, we decrease slc)
   VarOut = slc0 * lda
 
END FUNCTION Calcul_Slc

FUNCTION CalculSlc_haf (model, nodenumber, VarIn) RESULT(VarOut)
 USE DefUtils
 IMPLICIT NONE 
 TYPE(Model_t) :: model
 INTEGER :: nodenumber
 REAL (KIND=dp) :: VarIn(3) ! slipcoef, zs, bedrock
 REAL (KIND=dp) :: VarOut   ! slc

 TYPE(ValueList_t), POINTER :: material
 REAL(kind=dp) :: lda
 REAL(kind=dp) :: h_af
 REAL(kind=dp) :: h_af_init
 REAL(kind=dp) :: hth, zsl, rhoi, rhow
 
 ! inquire SSA friction exponent from Material properties
 material => GetMaterial()
 IF (.NOT. ASSOCIATED(material)) THEN
    CALL Fatal('SlipCoef_USF', "No material found?")
 ENDIF

 ! get needed variable
 hth  = ListGetConstReal( Material, 'SSA Friction Threshold Height',UnFoundFatal=.TRUE.) 
 zsl  = ListGetCReal( Model % Constants, 'Sea Level',UnFoundFatal=.TRUE.)
 rhoi = ListGetCReal( Model % Constants, 'Ice density',UnFoundFatal=.TRUE.)
 rhow = ListGetCReal( Model % Constants, 'water density',UnFoundFatal=.TRUE.)

 ! compute heigh above flotation (h_af)
 ! to distinguish later on flating and grounded part, haf use bedrock and not zb
 !    freeboard = ((rhow/rhoi)*(zsl - bedrock)+bedrock) 
 !    h_af = zs - freeboard
 h_af = VarIn(2) - ((rhow/rhoi)*(zsl - VarIn(3))+VarIn(3))

 ! compute scale scale factor  
 !     0 on floating part
 !     1 where above treshold
 ! [0-1] where between free floating and treshold

 ! general case
 lda=h_af/hth

 ! where floating => 0
 IF (lda.LE.0.) THEN
    lda=+0.0
 ENDIF

 ! haf superior to h_threshold => 1
 IF (h_af.GE.hth) THEN
 lda=+1.0
 ENDIF

 ! output : slc corrected by Haf (ie close to GL, we decrease slc)
 VarOut=VarIn(1)*lda
 
 END FUNCTION CalculSlc_haf
