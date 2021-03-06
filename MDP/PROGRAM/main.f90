PROGRAM SEQUENTIAL_MD
  !use MPI
  use READ_DATA
  use ALLOCATE_VARS
  use Inicialitzar
  use Distribucio_Uniforme_vel
  use Interaction_Cutoff_Modul
  use Verlet_Algorithm
  use Andersen_modul
  use Distribucio_Radial
  use Reescala_velocitats
  use parallel_routines

  IMPLICIT NONE
  INTEGER k, master_task

  call MPI_INIT(ierror)
  call MPI_COMM_RANK(MPI_COMM_WORLD,taskid,ierror)
  call MPI_COMM_SIZE(MPI_COMM_WORLD,numproc,ierror)
  taskid=taskid+1
  print*,taskid
  master_task=1
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)

  if(taskid.eq.master_task)then
    call srand(seed)
    !LLEGIM EL FITXER INPUT AMB LES SEGÜENTS DADES:
    !PARAMETRES DE DENSITAT, MASSA, TEMPERATURA DE REFERÈNCIA, TEMPERATURA DEL BANYS ETC.
    call read_all_data()
    !CALCULEM ELS PARÀMETRES GLOBALS DEL LATTICE: NÚMERO DE PARTÍCULES, LONGITUD DE LA CAIXA,
    !DISTANCIA ENTRE PARTICULES ETC.
    call other_global_vars()
    !PARALLELIZATION MPI SUBROUTINES IN ORDER TO DISTRIBUTE THE PARTICLES AMONG THE PROCESSORS
    call simple_loop_matrix()
    DO k=1,numproc
      print*,index_matrix(k,:)
    ENDDO
    call double_loop_matrix()
    DO k=1,numproc
      print*,double_matrix(k,:)
    ENDDO
  
  !INICITALITZEM LES VARIABLES D'ESTAT EN UNITATS REDUÏDES
  call INITIALIZE_VARS()
  !DEFINIM LA CONFIGURACIÓ INICIAL DE LES PARTICULES COM UNA XARXA FCC
  call FCC_Initialize(r)
  !LI DONEM UNA VELOCITAT INICIAL A LES PARTICULES (VELOCITATS INICIALS RANDOM)
  call Uniform_velocity(v,T_ini)
  !FEM UN REESCALATGE DE LES VELOCITATS A LA TEMPERATURA INICIAL
  !LI DONEM UNA TEMPERATURA INICIAL SUFICIENTMENT GRAN COM PER DESFER LA ESTRUCTURA
  !CRISTALINA (MELTING)
  call VELO_RESCALING_MOD(v,T_therm_prov)
  !UN COP CALCULAT EL NÚMERO DE ITERACIONS NECESSARIES PER FONDRE EL SÒLID INICIAL
  !APLIQUEM EL TERMOSTAT DE ANDERSEN TANTS COPS COM SIGUIN NECESSARIS
  !cutoff_aux=0.99*L*5d-1
  !CALL INTERACTION_CUTOFF(r,F,cutoff_aux)
  print*,'master of the initialization',taskid
  endif
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  IF(taskid.eq.master_task) THEN
  DO k=1,numproc-1
    print*,'bucle'
    CALL MPI_SEND(nworking_simple,1,MPI_INTEGER,k,nworking_simple,MPI_COMM_WORLD,ierror)
  END DO
  END IF
  !stop
  !call MPI_BARRIER(comm,ierror)
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  print*,'beafor melting',taskid,nworking_simple,nworking_double
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  !-------------------------------------------
  print*,'before finalize'
  CALL MPI_FINALIZE(ierror)
  print*,'after finalize'
  stop
  !-------------------------------------------
  DO i=1,3!n_melting
    print*,i,'task',taskid
    call MPI_BARRIER(MPI_COMM_WORLD,ierror)
    call velo_verlet(r,v,F) !EN UNA REGIÓ LxL AMB UNES CONDICIONS DE CONTORN PERIODIQUES
                            ! EN FUNCIO DE LES FORCES D'INTERACCIÓ S'ACTUALITZEN LES VELOCITATS
                            ! I LES POSICIONS DE LES PARTÍCULES
    print*,'mid bucle malting'
    call andersen(v,T_therm_prov) !AMB EL TERMOSTAT RECALCULEM LES VELOCITATS ARA EN FUNCIO
                                  ! DE LES TEMPERATURES
  end do
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  print*,'FINAL MELTING',taskid
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  !AMB EL SÒLID FOS I LES PARTICULES MOVENT-SE COM UN FLUID LES VELOCITATS ES REESCALEN CALCULANT
  !L'ENERGIA CINÈTICA DEGUDA A LA TEMPERATURA DE LES PARTÍCULES
  !COPIEM ELS PRIMERS RESULTATS DE LES PARTICULES COM A FLUID, VELOCITAT, POSICIONS, TEMPERATURES I
  !PRESSIÓ, EN UNITATS REDUÏDES I NO REDUÏDES I LES POSICIONS DE LES PARTÍCULES
  !I LES ESCRIBIIM EN UN FITXER OUTPUT
  call Velo_Rescaling(v,T_ini)
  open(51,file='thermodynamics_reduced.dat')
  open(52,file='thermodynamics_real.dat')
  open(53,file='distrib_funct.dat')
  open(54,file='positions.xyz')
  !APLIQUEM L'ALGORITME DE VERLET I EL TERMOSTAT D'ANDERSEN PER OBTENIR
  !VELOCITAT, POSICIONS, TEMPERATURES I
  !PRESSIÓ, EN UNITATS REDUÏDES I NO REDUÏDES, I LES POSICIONS DE LES PARTÍCULES
  !I LES ESCRIBIM EN UN FITXER OUTPUT, PER N TIME STEPS D'UN INTERVAL DE TEMPS
  !cutoff_aux=0.99*L*5d-1
  !CALL INTERACTION_CUTOFF(r,F,cutoff_aux)
  pressure=(density*temp_instant+pressure/(3d0*L**3d0))
  print*,'pres',press_re,pressure,pressure*press_re
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  print*,taskid
  call MPI_BARRIER(MPI_COMM_WORLD,ierror)
  DO i=1,n_verlet
    IF(taskid.eq.master_task) THEN
    t=t_a+i*h
    END IF
    CALL MPI_BARRIER(comm,ierror)
    call VELO_VERLET(r,v,F)
    if(is_thermostat.eqv..true.)THEN
      call andersen(v,T_therm)
    end if
  !PER OBTENIR LA DISTRIBUCIÓ RADIAL DE LES PARTÍCULES A CADA TIME STEP
  !DE LES PARTÍCULES DE LA REGIÓ DE LA CAIXA LI APLIQUEM LA FUNCIÍ G EN FUNCIÓ
  !DEL RADI
    IF (taskid.eq.master_task) THEN
      if((mod(i,n_meas).eq.0).and.(is_print_thermo.eqv..true.))then
        temp_instant=2d0*kinetic/(3d0*n_particles)
        pressure=(density*temp_instant+pressure/(3d0*L**3d0))
        write(51,*)t,kinetic,potential,(kinetic+potential),temp_instant,pressure
        write(52,*)t*time_re,kinetic*energy_re,potential*energy_re,(kinetic+potential)*energy_re,temp_instant*&
                                                                                      &temp_re,pressure*press_re
      endif
      if((mod(i,n_meas_gr).eq.0).and.(is_compute_gr.eqv..true.))then
        call RAD_DIST_INTER(r,g_r) !càlcul g(r) a cada pas
        n_gr_meas=n_gr_meas+1
      endif
      IF(is_time_evol.eqv..TRUE.)THEN
        WRITE(54,*)n_particles
        WRITE(54,*)
        DO k=1,n_particles
          WRITE(54,*)'X',r(k,:)
        END DO
      END IF
    END IF
  enddo
  IF (taskid.eq.master_task)then
    if((is_compute_gr.eqv..true.))then
      call RAD_DIST_INTER(r,g_r)
      n_gr_meas=n_gr_meas+1
      call RAD_DIST_FINAL(g_r,n_gr_meas) !càlcul g(r) com a cúmul
      do k=1,n_radial
        write(53,*)dx_radial*k,g_r(k)
      enddo
    endif
    print*,'PROGRAM END'
  END IF
  CALL MPI_FINALIZE(ierror)
END PROGRAM SEQUENTIAL_MD
