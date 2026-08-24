       FUNCTION passive_cond(Model,nodenumber,VarIn) RESULT(VarOut)
       USE DefUtils
       implicit none
       !-----------------
       TYPE(Model_t) :: Model
       INTEGER :: nodenumber
       REAL(kind=dp) :: VarIn,VarOut

       TYPE(ValueList_t),POINTER :: BodyForce,Material
       TYPE(Variable_t),POINTER :: HVar
       TYPE(Element_t), POINTER :: CurElement
       REAL(KIND=dp), PARAMETER :: EPS=EPSILON(1.0)
       REAL(KIND=dp), ALLOCATABLE,SAVE :: MinH(:),NodalH(:)
       INTEGER :: n
       LOGICAL,SAVE :: FirstTime=.True.
       LOGICAL :: GotIt

       IF (FirstTime) THEN
         n=Model % MaxElementNodes
         Allocate(MinH(n),NodalH(n))
         FirstTime=.False.
       END IF
 
       CurElement => GetCurrentElement()
       n  = GetElementNOFNodes(CurElement)

       BodyForce => GetBodyForce(CurElement)
       Material => GetMaterial(CurElement)
      
       ! Get Ice thickness
       HVar => VariableGet( Model%Mesh % Variables,'H',UnfoundFatal=.True.)
       CALL GetLocalSolution(NodalH,UElement=CurElement,UVariable=HVar)

       MinH = ListGetConstReal(BodyForce,'H Lower Limit', Gotit)
       IF (.NOT.Gotit) &
         MinH = ListGetConstReal(Material,'Min H', Gotit)
       IF (.NOT.GotIt) &
         CALL FATAL("passive_cond","Limit for H not found...")


       IF (ALL((NodalH(1:n)-EPS).LT.MinH(1:n))) THEN
        VarOut=+1._dp
       ELSE
        VarOut=-1.0_dp
      END IF

       End FUNCTION passive_cond
