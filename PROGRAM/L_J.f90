! Modul per calcular el potencial Lennard-Jones (en unitats reduides)
MODULE Lennard_Jones
use READ_DATA
implicit none
contains
SUBROUTINE L_J(d,ff,pot,cutoff)
    IMPLICIT NONE
    REAL*8 d,cutoff,ff,pot
    ff=(48d0/d**14d0)-(24d0/d**8d0)             ! F = -grad(V)
    pot=0d0
    IF (d<cutoff) THEN
        pot=4d0*((1d0/d**12d0)-(1d0/d**6d0))    ! potencial Lennard-Jones
    END IF
    RETURN
END SUBROUTINE L_J

END MODULE Lennard_Jones