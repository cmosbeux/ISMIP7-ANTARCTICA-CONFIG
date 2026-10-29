!/*****************************************************************************/
! *
! *  Elmer, A Finite Element Software for Multiphysical Problems
! *
! *  Copyright 1st April 1995 - , CSC - IT Center for Science Ltd., Finland
! *
! *  This program is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU General Public License
! *  as published by the Free Software Foundation; either version 2
! *  of the License, or (at your option) any later version.
! *
! *  This program is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! *  GNU General Public License for more details.
! *
! *  You should have received a copy of the GNU General Public License
! *  along with this program (in file fem/GPL-2); if not, write to the
! *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
! *  Boston, MA 02110-1301, USA.
! *
!/*****************************************************************************/
!  
!    Authors: Urruty, Caillet, Gillet-Chaulet, Mosbeux
!    Email:   cmosbeux@univ-gremoble-alpes.fr
!    Web:     http://www.csc.fi/elmer
!    Address: CSC - IT Center for Science Ltd.
!             Keilaranta 14
!             02101 Espoo, Finland
!  
!    Original Date: 2021
!    Modification:  26 October 2026
!/*****************************************************************************/

SUBROUTINE TransientMassBalance_SMB( Model,Solver,dt,TransientSimulation )
  
USE DefUtils
USE SolverUtils
USE ElementUtils

IMPLICIT NONE
TYPE(Model_t) :: Model
TYPE(Solver_t), TARGET :: Solver


TYPE(Variable_t), POINTER :: Accumulation,SurfGrad1,Surfgrad2,Time
TYPE(Variable_t), POINTER :: MB,Dens,Firn,SE,Melting,Refreeze,Raining,PotRad
TYPE(Variable_t), POINTER :: SMBref,Tref,PrecipRatio,TempAnomaly, ZsRef,Zs

TYPE(Mesh_t), POINTER :: Mesh
TYPE(Element_t),POINTER :: Element
TYPE(ValueList_t), POINTER :: SolverParams
INTEGER, POINTER :: NodeIndexes(:)

INTEGER :: n,i,j,k,cont,nb_surf,nb_vert,io,nb_day,it,day,YearDay,nb_jour,first_day,nb_line,i1,i2,nx,ny,nxDEM,nyDEM
INTEGER :: Node,month_index

REAL(KIND=dp) :: f, z, deg_pos,accu,melt_local, temp_10m,rain,t_simu,ksnow,kice,k0,T,dt
REAL(KIND=dp) :: interval_days,annual_factor,grad_temp,temp_sigma,pdd_threshold
REAL(KIND=dp) :: monthly_precipitation,monthly_melt,annual_smb
REAL(KIND=dp) :: reference_temperature,temperature_anomaly,surface_elevation,reference_elevation
REAL(KIND=dp) :: z_precip,grad_accu,grad,z_temp,seuil_precip,albedo_snow,albedo_ice,Rad_fact,alpha
REAL(KIND=dp) :: Pfact,temp_correc,firn_param,precip_correc,sigma,melt,ddf_ice

REAL(KIND=dp) :: Sr,rho_w,rho_ice,L_heat,T0,g1,g2,g3,Mean_Temp_Air,x_output,y_output

REAL(KIND=dp) :: DEMReliefRes,zDEM,x_ray,y_ray,z_ray,MaskRes

REAL(KIND=dp) :: fx,fy,slop,asp,S0,dr,lat,L,term1,term2,term3,tau_r,tau_d,tau_b,srad,sinAlpha,R,M,Is
REAL(KIND=dp) :: Ir,Iday,I0,hsr,hs,cos_i,dS,Idiff,reflec,Norm,year,x,y,yearstartdata,precip_fact,MinAltFact,MaxAltFact

REAL(KIND=dp), DIMENSION(:,:),allocatable :: Mask_l,DEMRelief_l,PotRadNodes
REAL(KIND=dp), DIMENSION(:,:,:),allocatable ::Mask,DEMRelief
REAL(KIND=dp), DIMENSION(:),ALLOCATABLE,SAVE :: AnnualPrecipNodes,AnnualMeltNodes

REAL(KIND=dp), DIMENSION(:),allocatable :: TempAirMoy,Precip,FirnNodes,MaskAccu

character(LEN=MAX_NAME_LEN) :: filenamePrecip,filenameMoy,filenameMaskRelief
CHARACTER(LEN=MAX_NAME_LEN) :: SMBrefName,TrefName,PrecipRatioName,TempAnomalyName, ZsRefName,ZsName
CHARACTER(LEN=MAX_NAME_LEN), SAVE :: fileMaskAccu                        

CHARACTER(LEN=MAX_NAME_LEN), SAVE :: SolverName='Transient Mass Balance'

LOGICAL :: firsttime=.true.,TransientSimulation, GotIt, Found, PrecipData, node_output=.false.,GotNode=.false.,Output1D,SigmaOK 
LOGICAL :: OutputFirn,OutputDens,OutputMelting,OutputAccumulation,Execute_steady=.true., UnFoundFatal=.TRUE.
LOGICAL :: OutputRefreeze,OutputRaining,OutputPotRad,TransientMB,MaskRelief,Obstacle,AccuCorrectionMask
LOGICAL :: RadiativeMode, ElevationFeedBackMode

INTEGER, SAVE :: month_counter=0

SAVE firsttime,nb_surf,nb_vert,TempAirMoy,nb_day,DEMReliefRes,AccuCorrectionMask,&
&PrecipData,Precip,PotRadNodes,FirnNodes,TransientMB,Execute_steady,&
&MaskAccu,MaskRelief,DEMRelief,nxDEM,nyDEM

SolverName = 'SMB_PDD'
SolverParams => GetSolverParams()
Mesh => Solver % Mesh


!===============================================================================
! Get solver parameters and field names
!===============================================================================

! Field names may be customized in the Solver section. Forcing fields are
! expected to be scalar nodal fields, refreshed monthly by their reader.
SMBrefName = ListGetString(SolverParams, 'Reference SMB Variable', Found)
IF (.NOT. Found) SMBrefName = 'SMBref'

! Required field names for the solver
TrefName = ListGetString(SolverParams, 'Reference Temperature Variable', Found)
IF (.NOT. Found) TrefName = 'Surface Temperature'
PrecipRatioName = ListGetString(SolverParams, 'Precipitation Ratio Variable', Found)
IF (.NOT. Found) PrecipRatioName = 'Precipitation Ratio'
TempAnomalyName = ListGetString(SolverParams, 'Temperature Anomaly Variable', Found)
IF (.NOT. Found) TempAnomalyName = 'Temperature Anomaly'


WRITE(*,*) 'Getting mandatory variables'

! Get the mendatory variables
SMBref => VariableGet(Mesh % Variables, TRIM(SMBrefName), UnFoundFatal=.TRUE.)
PrecipRatio => VariableGet(Mesh % Variables, TRIM(PrecipRatioName), UnFoundFatal=.TRUE.)

Tref => GetNodalVariable(TrefName)
TempAnomaly => GetNodalVariable(TempAnomalyName)


! Activate radiative mode if specified in the solver parameters
RadiativeMode = ListGetLogical(SolverParams, 'Radiative Mode', Found)
IF (.NOT. Found) RadiativeMode = .FALSE.

IF (RadiativeMode) THEN
  SurfGrad1 => VariableGet(Model % Variables, 'SurfGrad 1', UnFoundFatal=.TRUE.)
  SurfGrad2 => VariableGet(Model % Variables, 'SurfGrad 2', UnFoundFatal=.TRUE.)
END IF

WRITE(*,*) 'Radiative mode: ', RadiativeMode

! Activate elevation feedback mode if specified in the solver parameters
ElevationFeedBackMode = ListGetLogical(SolverParams, 'Elevation Feedback Mode', Found)
IF (.NOT. Found) ElevationFeedBackMode = .FALSE.

WRITE(*,*) 'Feedback mode: ', ElevationFeedBackMode

! If Elevation Feedback mode is activated, we need to get the reference and actual elevation to correct temperature and precipitation 
IF (ElevationFeedBackMode) THEN

  ! Referene surface
  ZsrefName = ListGetString(SolverParams, 'Reference Elevation Variable', Found)
  IF (.NOT. Found) THEN
    ZsrefName = 'ZsRef'
    CALL INFO(SolverName, 'Reference Elevation variable Name not set, using '//TRIM(ZsrefName),level=3)
  END IF

  ! Evolving surface
  ZsName = ListGetString(SolverParams, 'Elevation Variable', Found)
  IF (.NOT. Found) THEN
    ZsName = 'Zs'
    CALL INFO(SolverName, 'Elevation variable Name not set, using '//TRIM(ZsName),level=3)
  END IF

  ZsRef => GetNodalVariable(ZsRefName)
  Zs => GetNodalVariable(ZsName)
  IF (ZsRef % DOFs /= 1 .OR. Zs % DOFs /= 1) &
    CALL FATAL(SolverName,'Elevation fields must be scalar')

END IF

WRITE(*,*) 'Getting optional variables for mass balance'


! Get the variable defined in the model for mass balance
MB => VariableGet(Model % Variables, 'Mass Balance', UnFoundFatal=.TRUE.)

IF (dt <= 0.0_dp) CALL FATAL(SolverName, 'Timestep must be positive')
interval_days = dt * 365 
nb_jour = MAX(NINT(interval_days), 1)
annual_factor = 365 / REAL(nb_jour, KIND=dp)

! Retrieve reference energy-balance parameters for the optional radiation path.
z_temp = GetConstReal(Model % Constants, 'z_temp')
seuil_precip = GetConstReal(Model % Constants, 'seuil_precip')
Rad_fact = GetConstReal(Model % Constants, 'RadFact')
albedo_ice = GetConstReal(Model % Constants, 'Albedo_ice')
albedo_snow = GetConstReal(Model % Constants, 'Albedo_snow')
kice = GetConstReal(Model % Constants, 'kice')
ksnow = GetConstReal(Model % Constants, 'ksnow')
k0 = GetConstReal(Model % Constants, 'k0')
firn_param = GetConstReal(Model % Constants, 'firn_param')
rho_w = GetConstReal(Model % Constants, 'Water Density')
rho_ice = GetConstReal(Model % Constants, 'Ice Density')
L_heat = GetConstReal(Model % Constants, 'L_heat')
temp_sigma = GetConstReal(Model % Constants, 'Temperature Sigma', Found)
IF (.NOT. Found) temp_sigma = 5.0_dp
temp_correc = GetConstReal(Model % Constants, 'TempCorrec', Found)
IF (.NOT. Found) temp_correc = 0.0_dp

! Retrieve temperature gradient for lapse rate correction (based on PISM and other models)
grad_temp = GetConstReal(Model % Constants, 'GradTemp', Found)
IF (.NOT. Found) grad_temp = -0.0065_dp

pdd_threshold = GetConstReal(Model % Constants, 'PDD Melt Temperature', Found)
IF (.NOT. Found) pdd_threshold = 0.0_dp


! Ice-only degree-day factor in m w.e. per (degree C day). This value seems to be used in PISM for Antartica 
ddf_ice = GetConstReal(Model % Constants, 'DDF Ice', Found)
IF (.NOT. Found) ddf_ice = 0.00879_dp
IF (ddf_ice < 0.0_dp) CALL FATAL(SolverName, 'DDF Ice cannot be negative')


WRITE(*,*) 'Initializing spatial data for mass-balance computation'


! Initialize accumulators and seed the first annual SMB from reference SMB.
IF (firsttime) THEN

  CALL INITIALIZE_SPATIAL_DATA()


  IF (SMBref % DOFs /= 1) &
    CALL FATAL(SolverName, 'Annual SMB reference must be a scalar nodal field')
  DO Node = 1, Model % NumberOfNodes
    IF (MB % Perm(Node) <= 0 .OR. SMBref % Perm(Node) <= 0) CYCLE
    MB % Values(MB % Perm(Node)) = &
      MAX(SMBref % Values(SMBref % Perm(Node)), 0.0_dp) 
  END DO
  firsttime = .FALSE.
END IF


IF (RadiativeMode) &
  CALL FATAL(SolverName, 'Radiative Mode is not implemented in the monthly PDD path')


month_index = MOD(month_counter, 12) + 1
WRITE(*,*) 'Month index: ', month_index, '/12'

IF (Tref % DOFs /= 1 .OR. TempAnomaly % DOFs /= 1) &
  CALL FATAL(SolverName,'Reference temperature and temperature anomaly must be scalar fields')

! Loop over all nodes to compute monthly precipitation and melt
DO Node = 1, Model % NumberOfNodes
  IF (MB % Perm(Node) <= 0) CYCLE

  monthly_precipitation = ComputePrecipitation(Node)
  monthly_melt = 0.0_dp
  surface_elevation = 0.0_dp
  reference_elevation = 0.0_dp
  IF (Tref % Perm(Node) > 0 .AND. TempAnomaly % Perm(Node) > 0) THEN
    reference_temperature = Tref % Values(Tref % Perm(Node))
    temperature_anomaly = TempAnomaly % Values(TempAnomaly % Perm(Node))

    IF (ElevationFeedBackMode) THEN
      IF (Zs % Perm(Node) > 0 .AND. ZsRef % Perm(Node) > 0) THEN
        surface_elevation = Zs % Values(Zs % Perm(Node))
        reference_elevation = ZsRef % Values(ZsRef % Perm(Node))

        monthly_melt = Melt_Degree_Month(reference_temperature,temperature_anomaly,month_index, &
             ElevationFeedBackMode,grad_temp,surface_elevation,reference_elevation, &
             temp_correc,temp_sigma,pdd_threshold,ddf_ice)
      END IF
    ELSE
      monthly_melt = Melt_Degree_Month(reference_temperature,temperature_anomaly,month_index, &
           ElevationFeedBackMode,grad_temp,surface_elevation,reference_elevation, &
           temp_correc,temp_sigma,pdd_threshold,ddf_ice)
    END IF
  END IF
  AnnualPrecipNodes(Node) = AnnualPrecipNodes(Node) + monthly_precipitation
  AnnualMeltNodes(Node) = AnnualMeltNodes(Node) + monthly_melt

  IF (month_index == 12) THEN
    annual_smb = AnnualPrecipNodes(Node) - AnnualMeltNodes(Node)
    MB % Values(MB % Perm(Node)) = annual_smb
    AnnualPrecipNodes(Node) = 0.0_dp
    AnnualMeltNodes(Node) = 0.0_dp
  END IF
END DO
month_counter = MOD(month_counter + 1, 12)

!===============================================================================
!===============================================================================

CONTAINS

  SUBROUTINE INITIALIZE_SPATIAL_DATA()
    INTEGER :: node, active_nodes

    ! Read optional raster inputs, then allocate node-based working arrays.
    filenameMaskRelief = ListGetString(Model % Constants, 'MaskReliefFile', MaskRelief)
    fileMaskAccu = ListGetString(Model % Constants, 'MaskAccuFile', AccuCorrectionMask)

    active_nodes = 0
    DO node = 1, Model % NumberOfNodes
      IF (MB % Perm(node) /= 0) active_nodes = active_nodes + 1
    END DO
    IF (active_nodes <= 0) CALL FATAL(SolverName, 'No active mass-balance nodes found')

    nb_surf = active_nodes
    nb_vert = Model % NumberOfNodes / active_nodes
    ALLOCATE(FirnNodes(Model % NumberOfNodes), &
         PotRadNodes(365, Model % NumberOfNodes), &
         AnnualPrecipNodes(Model % NumberOfNodes), &
         AnnualMeltNodes(Model % NumberOfNodes), &
         MaskAccu(Model % NumberOfNodes))
    FirnNodes = 2.0_dp
    PotRadNodes = 0.0_dp
    AnnualPrecipNodes = 0.0_dp
    AnnualMeltNodes = 0.0_dp
    MaskAccu = 1.0_dp

    IF (MaskRelief) CALL READ_RELIEF_GRID()
    IF (AccuCorrectionMask) CALL READ_ACCUMULATION_MASK()
  END SUBROUTINE INITIALIZE_SPATIAL_DATA


  SUBROUTINE COMPUTE_POTENTIAL_RADIATION()
    INTEGER :: node, day_of_year

    DO node = 1, Model % NumberOfNodes
      IF (MB % Perm(node) <= 0) CYCLE
      DO day_of_year = 1, 365
        PotRadNodes(day_of_year, node) = &
          PotentialRadiation(node, day_of_year)
      END DO
    END DO
  END SUBROUTINE COMPUTE_POTENTIAL_RADIATION


  SUBROUTINE READ_RELIEF_GRID()
    INTEGER :: line, ios, count, row_count
    REAL(KIND=dp), ALLOCATABLE :: ReliefPoints(:,:)

    OPEN(UNIT=91, FILE=TRIM(filenameMaskRelief), STATUS='old', IOSTAT=ios)
    IF (ios /= 0) CALL FATAL(SolverName, 'Cannot open MaskReliefFile')
    nb_line = 0
    DO
      READ(91, *, IOSTAT=ios)
      IF (ios /= 0) EXIT
      nb_line = nb_line + 1
    END DO
    CLOSE(91)
    IF (nb_line < 4) CALL FATAL(SolverName, 'Relief grid must contain at least 2 by 2 points')

    ALLOCATE(ReliefPoints(nb_line, 3))
    OPEN(UNIT=91, FILE=TRIM(filenameMaskRelief), STATUS='old', IOSTAT=ios)
    IF (ios /= 0) CALL FATAL(SolverName, 'Cannot reopen MaskReliefFile')
    DO line = 1, nb_line
      READ(91, *, IOSTAT=ios) ReliefPoints(line, 1:3)
      IF (ios /= 0) CALL FATAL(SolverName, 'Invalid row in MaskReliefFile')
    END DO
    CLOSE(91)

    nxDEM = 1
    DO WHILE (nxDEM < nb_line)
      IF (ReliefPoints(nxDEM, 2) /= ReliefPoints(nxDEM + 1, 2)) EXIT
      nxDEM = nxDEM + 1
    END DO
    nyDEM = 1
    DO WHILE (nyDEM < nb_line)
      IF (ReliefPoints(nyDEM, 1) /= ReliefPoints(nyDEM + 1, 1)) EXIT
      nyDEM = nyDEM + 1
    END DO

    IF (nxDEM == 1) THEN
      IF (nyDEM < 2 .OR. MOD(nb_line, nyDEM) /= 0) &
        CALL FATAL(SolverName, 'Cannot determine relief-grid dimensions')
      nxDEM = nb_line / nyDEM
      ALLOCATE(DEMRelief(nyDEM, nxDEM, 3))
      count = 0
      DO line = 1, nxDEM
        DO row_count = 1, nyDEM
          count = count + 1
          DEMRelief(row_count, line, :) = ReliefPoints(count, :)
        END DO
      END DO
    ELSE
      IF (nxDEM < 2 .OR. MOD(nb_line, nxDEM) /= 0) &
        CALL FATAL(SolverName, 'Cannot determine relief-grid dimensions')
      nyDEM = nb_line / nxDEM
      IF (nyDEM < 2) CALL FATAL(SolverName, 'Relief grid must contain at least 2 rows')
      ALLOCATE(DEMRelief(nyDEM, nxDEM, 3))
      count = 0
      DO row_count = 1, nyDEM
        DO line = 1, nxDEM
          count = count + 1
          DEMRelief(row_count, line, :) = ReliefPoints(count, :)
        END DO
      END DO
    END IF

    DEMReliefRes = ABS(DEMRelief(1, 1, 1) - DEMRelief(1, 2, 1))
    IF (DEMReliefRes <= 0.0_dp) CALL FATAL(SolverName, 'Invalid relief-grid spacing')
    DEALLOCATE(ReliefPoints)
  END SUBROUTINE READ_RELIEF_GRID


  SUBROUTINE READ_ACCUMULATION_MASK()
    INTEGER :: line, ios, count, row_count, mask_nx, mask_ny, ix, iy, node
    REAL(KIND=dp) :: x_node, y_node
    REAL(KIND=dp), ALLOCATABLE :: MaskPoints(:,:)

    OPEN(UNIT=92, FILE=TRIM(fileMaskAccu), STATUS='old', IOSTAT=ios)
    IF (ios /= 0) CALL FATAL(SolverName, 'Cannot open MaskAccuFile')
    nb_line = 0
    DO
      READ(92, *, IOSTAT=ios)
      IF (ios /= 0) EXIT
      nb_line = nb_line + 1
    END DO
    CLOSE(92)
    IF (nb_line < 4) CALL FATAL(SolverName, 'Accumulation mask must contain at least 2 by 2 points')

    ALLOCATE(MaskPoints(nb_line, 3))
    OPEN(UNIT=92, FILE=TRIM(fileMaskAccu), STATUS='old', IOSTAT=ios)
    IF (ios /= 0) CALL FATAL(SolverName, 'Cannot reopen MaskAccuFile')
    DO line = 1, nb_line
      READ(92, *, IOSTAT=ios) MaskPoints(line, 1:3)
      IF (ios /= 0) CALL FATAL(SolverName, 'Invalid row in MaskAccuFile')
    END DO
    CLOSE(92)

    mask_nx = 1
    DO WHILE (mask_nx < nb_line)
      IF (MaskPoints(mask_nx, 2) /= MaskPoints(mask_nx + 1, 2)) EXIT
      mask_nx = mask_nx + 1
    END DO
    mask_ny = 1
    DO WHILE (mask_ny < nb_line)
      IF (MaskPoints(mask_ny, 1) /= MaskPoints(mask_ny + 1, 1)) EXIT
      mask_ny = mask_ny + 1
    END DO

    IF (mask_nx == 1) THEN
      IF (mask_ny < 2 .OR. MOD(nb_line, mask_ny) /= 0) &
        CALL FATAL(SolverName, 'Cannot determine accumulation-mask dimensions')
      mask_nx = nb_line / mask_ny
      ALLOCATE(Mask(mask_ny, mask_nx, 3))
      count = 0
      DO line = 1, mask_nx
        DO row_count = 1, mask_ny
          count = count + 1
          Mask(row_count, line, :) = MaskPoints(count, :)
        END DO
      END DO
    ELSE
      IF (mask_nx < 2 .OR. MOD(nb_line, mask_nx) /= 0) &
        CALL FATAL(SolverName, 'Cannot determine accumulation-mask dimensions')
      mask_ny = nb_line / mask_nx
      IF (mask_ny < 2) CALL FATAL(SolverName, 'Accumulation mask must contain at least 2 rows')
      ALLOCATE(Mask(mask_ny, mask_nx, 3))
      count = 0
      DO row_count = 1, mask_ny
        DO line = 1, mask_nx
          count = count + 1
          Mask(row_count, line, :) = MaskPoints(count, :)
        END DO
      END DO
    END IF

    MaskRes = ABS(Mask(1, 1, 1) - Mask(1, 2, 1))
    IF (MaskRes <= 0.0_dp) CALL FATAL(SolverName, 'Invalid accumulation-mask grid spacing')
    DO node = 1, Model % NumberOfNodes
      x_node = Model % Nodes % x(node)
      y_node = Model % Nodes % y(node)
      ix = FLOOR((x_node - Mask(1, 1, 1)) / MaskRes) + 1
      iy = FLOOR((y_node - Mask(1, 1, 2)) / MaskRes) + 1

      IF (iy <= 1 .OR. iy >= mask_ny .OR. ix <= 1 .OR. ix >= mask_nx) THEN
        MaskAccu(node) = 1.0_dp
      ELSE
        MaskAccu(node) = &
          Mask(iy, ix, 3) * (Mask(iy, ix + 1, 1) - x_node) * &
            (Mask(iy + 1, ix, 2) - y_node) + &
          Mask(iy, ix + 1, 3) * (x_node - Mask(iy, ix, 1)) * &
            (Mask(iy + 1, ix, 2) - y_node) + &
          Mask(iy + 1, ix, 3) * (Mask(iy, ix + 1, 1) - x_node) * &
            (y_node - Mask(iy, ix, 2)) + &
          Mask(iy + 1, ix + 1, 3) * (x_node - Mask(iy, ix, 1)) * &
            (y_node - Mask(iy, ix, 2))
        MaskAccu(node) = MaskAccu(node) / MaskRes**2
      END IF
    END DO

    DEALLOCATE(MaskPoints, Mask)
  END SUBROUTINE READ_ACCUMULATION_MASK


  !===============================================================================
  ! Function to get nodal variable from model mesh or variables
  !===============================================================================
  FUNCTION GetNodalVariable(VariableName) RESULT(Field)
    CHARACTER(LEN=*), INTENT(IN) :: VariableName
    TYPE(Variable_t), POINTER :: Field

    Field => VariableGet(Model % Mesh % Variables, TRIM(VariableName))
    IF (.NOT. ASSOCIATED(Field)) THEN
      Field => VariableGet(Model % Variables, TRIM(VariableName), UnFoundFatal=.TRUE.)
    END IF
    IF (.NOT. ASSOCIATED(Field % Perm)) THEN
      CALL FATAL(SolverName, 'Input variable has no nodal permutation: '//TRIM(VariableName))
    END IF
    IF (.NOT. ASSOCIATED(Field % Values)) THEN
      CALL FATAL(SolverName, 'Input variable has no values: '//TRIM(VariableName))
    END IF
    IF (Field % TYPE /= Variable_on_nodes) THEN
      CALL FATAL(SolverName, 'Input variable is not nodal: '//TRIM(VariableName))
    END IF
  END FUNCTION GetNodalVariable


  !===============================================================================
  ! Function to compute potential solar radiation for a given node and day of year
  !===============================================================================
  FUNCTION PotentialRadiation(Node, DayOfYear) RESULT(Radiation)
    INTEGER, INTENT(IN) :: Node, DayOfYear
    REAL(KIND=dp) :: Radiation
    REAL(KIND=dp) :: fx, fy, slope, aspect, latitude, dr, L
    REAL(KIND=dp) :: term1, term2, term3, S0, I0, dS, hsr, hs
    REAL(KIND=dp) :: sinAlpha, airMass, tau_b, tau_d, tau_r
    REAL(KIND=dp) :: cos_i, Is, direct, diffuse, reflected, albedo
    REAL(KIND=dp) :: hourRadiation, solarCosine, solarAltitude
    REAL(KIND=dp) :: x_ray, y_ray, z_ray, z_dem, alpha, grid_x, grid_y
    INTEGER :: hour, sunHours, ray_step, i_grid, j_grid
    LOGICAL :: obstacle

    dr = ACOS(-1.0_dp) / 180.0_dp
    S0 = 1367.0_dp
    latitude = GetConstReal(Model % Constants, 'Latitude')
    L = latitude * dr
    fx = SurfGrad1 % Values(SurfGrad1 % Perm(Node))
    fy = SurfGrad2 % Values(SurfGrad2 % Perm(Node))
    slope = ATAN(SQRT(fx * fx + fy * fy))
    aspect = -ATAN2(fx, fy)

    term1 = SIN(L) * COS(slope) - COS(L) * SIN(slope) * COS(aspect)
    term2 = COS(L) * COS(slope) + SIN(L) * SIN(slope) * COS(aspect)
    term3 = SIN(slope) * SIN(aspect)
    
    I0 = S0 * (1.0_dp + 0.0344_dp * COS(360.0_dp * dr * &
         (194.0_dp + REAL(DayOfYear, KIND=dp)) / 365.0_dp))
    dS = 23.45_dp * dr * SIN(360.0_dp * dr * &
         (284.0_dp + REAL(DayOfYear, KIND=dp)) / 365.0_dp)
    solarCosine = -TAN(L) * TAN(dS)

    IF (solarCosine >= 1.0_dp) THEN
      Radiation = 0.0_dp
      RETURN
    ELSEIF (solarCosine <= -1.0_dp) THEN
      hsr = ACOS(-1.0_dp)
    ELSE
      hsr = ACOS(solarCosine)
    END IF
    sunHours = NINT(24.0_dp * hsr / ACOS(-1.0_dp))
    hourRadiation = 0.0_dp
    albedo = 0.6_dp

    DO hour = 1, sunHours
      hs = hsr - 15.0_dp * dr * REAL(hour, KIND=dp)
      sinAlpha = SIN(L) * SIN(dS) + COS(L) * COS(dS) * COS(hs)
      IF (sinAlpha <= 0.0_dp) CYCLE

      airMass = SQRT(1229.0_dp + (614.0_dp * sinAlpha)**2) - 614.0_dp * sinAlpha
      tau_b = 0.56_dp * (EXP(-0.65_dp * airMass) + EXP(-0.095_dp * airMass))
      tau_d = 0.271_dp - 0.294_dp * tau_b
      tau_r = 0.271_dp + 0.706_dp * tau_b
      cos_i = SIN(dS) * term1 + COS(dS) * COS(hs) * term2 + &
              COS(dS) * term3 * SIN(hs)
      Is = I0 * tau_b
      direct = MAX(Is * cos_i, 0.0_dp)
      diffuse = I0 * tau_d * COS(slope)**2 / 2.0_dp * sinAlpha
      reflected = I0 * albedo * tau_r * SIN(slope)**2 / 2.0_dp * sinAlpha

      IF (MaskRelief) THEN
        solarAltitude = MAX(MIN(sinAlpha, 1.0_dp), -1.0_dp)
        alpha = ASIN(solarAltitude)
        x_ray = Model % Nodes % x(Node)
        y_ray = Model % Nodes % y(Node)
        z_ray = Model % Nodes % z(Node)
        obstacle = .FALSE.

        DO ray_step = 1, 20
          z_ray = z_ray + 500.0_dp * SIN(alpha)
          x_ray = x_ray + 500.0_dp * COS(alpha) * SIN(alpha)
          y_ray = y_ray - 500.0_dp * COS(alpha) * COS(hs)

          i_grid = FLOOR((x_ray - DEMRelief(1, 1, 1)) / DEMReliefRes) + 1
          j_grid = FLOOR((y_ray - DEMRelief(1, 1, 2)) / DEMReliefRes) + 1
          IF (j_grid <= 1 .OR. j_grid >= nyDEM .OR. &
              i_grid <= 1 .OR. i_grid >= nxDEM) CYCLE

          grid_x = x_ray - DEMRelief(i_grid, j_grid, 1)
          grid_y = y_ray - DEMRelief(i_grid, j_grid, 2)
          z_dem = &
            DEMRelief(j_grid, i_grid, 3) * &
              (DEMRelief(j_grid, i_grid + 1, 1) - x_ray) * &
              (DEMRelief(j_grid + 1, i_grid, 2) - y_ray) + &
            DEMRelief(j_grid, i_grid + 1, 3) * grid_x * &
              (DEMRelief(j_grid + 1, i_grid, 2) - y_ray) + &
            DEMRelief(j_grid + 1, i_grid, 3) * &
              (DEMRelief(j_grid, i_grid + 1, 1) - x_ray) * grid_y + &
            DEMRelief(j_grid + 1, i_grid + 1, 3) * grid_x * grid_y
          z_dem = z_dem / DEMReliefRes**2
          IF (z_ray < z_dem) obstacle = .TRUE.
        END DO

        IF (obstacle) direct = 0.0_dp
      END IF

      hourRadiation = hourRadiation + MAX(direct + diffuse + reflected, 0.0_dp)
    END DO

    Radiation = hourRadiation / 24.0_dp
  END FUNCTION PotentialRadiation


  FUNCTION Melt_Degree_Month(reference_temperature,temperature_anomaly,month, &
       elevation_feedback_enabled,temperature_lapse_rate,surface_elevation, &
       reference_elevation,temperature_correction,temperature_sigma, &
       melt_temperature_threshold,ice_degree_day_factor) RESULT(monthly_melt)
    REAL(KIND=dp), INTENT(IN) :: reference_temperature,temperature_anomaly
    INTEGER, INTENT(IN) :: month
    LOGICAL, INTENT(IN) :: elevation_feedback_enabled
    REAL(KIND=dp), INTENT(IN) :: temperature_lapse_rate,surface_elevation,reference_elevation
    REAL(KIND=dp), INTENT(IN) :: temperature_correction,temperature_sigma
    REAL(KIND=dp), INTENT(IN) :: melt_temperature_threshold,ice_degree_day_factor
    REAL(KIND=dp) :: monthly_melt,mean_temperature,expected_degree_days
    REAL(KIND=dp) :: standardized_temperature,sqrt_two,sqrt_two_pi
    INTEGER, PARAMETER :: month_days(12) = &
      (/ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /)

    IF (month < 1 .OR. month > SIZE(month_days)) &
      CALL FATAL(SolverName,'Month index must be between 1 and 12')
    IF (temperature_sigma < 0.0_dp) &
      CALL FATAL(SolverName,'Temperature Sigma cannot be negative')
    IF (ice_degree_day_factor < 0.0_dp) &
      CALL FATAL(SolverName,'DDF Ice cannot be negative')

    mean_temperature = reference_temperature + temperature_anomaly + temperature_correction
    IF (elevation_feedback_enabled) THEN
      mean_temperature = mean_temperature + temperature_lapse_rate * &
           (surface_elevation - reference_elevation)
    END IF

    IF (temperature_sigma <= 0.0_dp) THEN
      expected_degree_days = MAX(mean_temperature - melt_temperature_threshold,0.0_dp)
    ELSE
      sqrt_two = SQRT(2.0_dp)
      sqrt_two_pi = SQRT(2.0_dp * ACOS(-1.0_dp))
      standardized_temperature = (mean_temperature - melt_temperature_threshold) / temperature_sigma
      expected_degree_days = &
        temperature_sigma / sqrt_two_pi * EXP(-0.5_dp * standardized_temperature**2) + &
        0.5_dp * (mean_temperature - melt_temperature_threshold) * &
        (1.0_dp + ERF(standardized_temperature / sqrt_two))
    END IF

    monthly_melt = ice_degree_day_factor * expected_degree_days * &
         REAL(month_days(month),KIND=dp)
  END FUNCTION Melt_Degree_Month


  FUNCTION ComputePrecipitation(Node)
    INTEGER, INTENT(IN) :: Node
    REAL(KIND=dp) :: ComputePrecipitation
    REAL(KIND=dp) :: reference_precipitation, precipitation_ratio

    ! SMBref is annual reference precipitation; ratio is this month's share.
    IF (SMBref % DOFs /= 1) &
      CALL FATAL(SolverName, 'Annual SMB reference must be a scalar nodal field')
    IF (PrecipRatio % DOFs /= 1) &
      CALL FATAL(SolverName, 'Monthly precipitation ratio must be a scalar nodal field')
    IF (SMBref % Perm(Node) <= 0 .OR. PrecipRatio % Perm(Node) <= 0) THEN
      ComputePrecipitation = 0.0_dp
      RETURN
    END IF

    ! annual precipitation should be divided by 12 to get monthly precipitation 
    reference_precipitation = MAX(SMBref % Values(SMBref % Perm(Node)), 0.0_dp)
    precipitation_ratio = PrecipRatio % Values(PrecipRatio % Perm(Node))
    IF (precipitation_ratio < 0.0_dp) &
      CALL FATAL(SolverName, 'Precipitation Ratio cannot be negative')

    ComputePrecipitation = reference_precipitation * precipitation_ratio / 12.0_dp

  END FUNCTION ComputePrecipitation


END SUBROUTINE TransientMassBalance_SMB
