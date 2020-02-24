! Moduls de Lennard Jones, Periodic Bounday Conditions, Interaction Cutoff, velocitats distribuïdes uniformement, Velocity Verlet


! Modul per la distribucio uniforme de les velocitats
MODULE Distribucio_Uniforme_vel
use READ_DATA
implicit none
contains
SUBROUTINE UNIFORM_VELO(velocity,T)
    REAL*8 :: density,L,a
    INTEGER :: n_particles,M,i,j,seed
    REAL*8 :: velocity(n_particles,3),vi,vtot,T
    COMMON/PARAMETERS/n_particles,M,density,L,a
    
    seed=13
    CALL SRAND(seed)
    
    DO i=1,3
        vtot=0
        
        DO j=1,n_particles-1
            vi=2*RAND()-1
            velocity(j,i)=vi
            vtot=vtot+vi
        END DO
        velocity(n_particles,i)=-vtot
     END DO
     
     !Resacling the velocities to the temperature
     CALL VELO_RESCALING(velocity,T)
     RETURN
END SUBROUTINE UNIFORM_VELO

END MODULE Distribucio_Uniforme_vel


! Modul del cutoff
MODULE Interaction_Cutoff_Modul
use READ_DATA
implicit none
contains
SUBROUTINE INTERACTION_CUTOFF(positions,F,E,PBC,cutoff,pressure)
!COMPUTING THE TOTAL INTERACTION ENERGY GIVEN AN EXTENAL FUNCTION FOR POTENCIAL
!AND BOUNDARY CONDITIONS
    IMPLICIT NONE
    INTEGER :: n_particles,M,i,j
    REAL*8 :: cutoff,density,L,a,PBC,E,pot,pressure
    REAL*8 :: dx,dy,dz,d,ff
    REAL*8, DIMENSION(n_particles,3) :: positions, F
    COMMON/PARAMETERS/n_particles,M,density,L,a
    !print*,'in inter'
    F=0d0
    E=0d0
    !print*,'hola-1'
    pressure=0.0
    !print*,'hola'
    DO i=1,n_particles
        DO j=i+1,n_particles
            dx=PBC(positions(i,1)-positions(j,1),L)
            dy=PBC(positions(i,2)-positions(j,2),L)
            dz=PBC(positions(i,3)-positions(j,3),L)
            d=(dx**2d0+dy**2d0+dz**2d0)**0.5
            
            CALL L_J(d,ff,pot,cutoff)
            F(i,1)=F(i,1)+ff*dx
            F(i,2)=F(i,2)+ff*dy
            F(i,3)=F(i,3)+ff*dz
            F(j,1)=F(j,1)-ff*dx
            F(j,2)=F(j,2)-ff*dy
            F(j,3)=F(j,3)-ff*dz
            E=E+pot
            !print*,'hola1'
            pressure=pressure+(ff*dx**2d0+ff*dy**2d0+ff*dz**2d0)
            !print*,'hola2'
        END DO
    END DO
    !print*,'en inter'
    RETURN
END SUBROUTINE INTERACTION_CUTOFF

END MODULE Interaction_Cutoff_Modul


! Modul del Lennard-Jones
MODULE Lennard_Jones
use READ_DATA
implicit none
contains
SUBROUTINE L_J(d,F,pot,cutoff)
    IMPLICIT NONE
    REAL*8 d,cutoff,F,pot
    F=(48d0/d**14d0)-(24d0/d**8d0)
    pot=0d0
    IF (d<cutoff) THEN
        pot=4d0*((1d0/d**12d0)-(1d0/d**6d0))
    END IF
    RETURN
END SUBROUTINE L_J

END MODULE Lennard_Jones


! Modul de les condicions periodiques de contorn
MODULE PBC
use READ_DATA
implicit none
contains

