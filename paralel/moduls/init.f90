module init
  use def_variables
  use Forces_LJ
  use mpi_vars

  contains

! Initialization of particles position (square lattice) and velocity (thermal random distribution) and compute initial forces
  subroutine initialize()
    integer :: side, i, j, k, count, size_seed
    real(8) :: dx, U1, U2, U3, U4 ! U[1-4] are random variables
    integer, allocatable :: seed_array(:)
    time    = 0.d0
    pi      = acos(-1.d0)
    gdr_int = 0

! Initializing random numbers
    call random_seed(size=size_seed)
    allocate(seed_array(size_seed))
    seed_array(:) = seed*(workerid+1)
    call random_seed(put=seed_array)

! mesuring the number of simple cubic cells per side
    side = int(dble(Npart)**(1.d0/3.d0))+1
    dx = L/dble(side) ! separation between particles
    if (workerid==master) then
        count= 0
        do i = 1, side
          do j = 1, side
            do k = 1, side
              if (count < Npart) then
                count = count+1
                pos(count, :) = dble((/i, j, k/)) * dx

                ! generating thermal velocities using Box-Müller algorithm
                call random_number(U1)
                call random_number(U2)
                call random_number(U3)
                call random_number(U4)
                vel(count,1)=sqrt(-2.d0*temp*log(U1))*cos(2.d0*pi*U2)
                vel(count,2)=sqrt(-2.d0*temp*log(U1))*sin(2.d0*pi*U2)
                vel(count,3)=sqrt(-2.d0*temp*log(U3))*cos(2.d0*pi*U4)
              end if
            end do
          end do
        end do
! making general velocity = zero
      vel(:,1) = vel(:,1) - sum(vel(:,1))/dble(Npart)
      vel(:,2) = vel(:,2) - sum(vel(:,2))/dble(Npart)
      vel(:,3) = vel(:,3) - sum(vel(:,3))/dble(Npart)

! center system at 0.0
      pos = pos - L/2.d0
    endif
! sharing initial position and velocities between workers and computing forces
  call MPI_BCAST(pos, (Npart*3), MPI_DOUBLE_PRECISION, master, MPI_COMM_WORLD, IERROR)
  call MPI_BCAST(vel, (Npart*3), MPI_DOUBLE_PRECISION, master, MPI_COMM_WORLD, IERROR)
  call ForcesLJ()

! opening output data file
  if (workerid==master) then
  open(unit=un_mag,file='output/results.log')
  write(un_mag,'(6a16)' ) '#Time_(ps)','Temp_(K)','E_kin_(kJ/mol)','E_pot_(kJ/mol)','E_tot_(kJ/mol)','Pressure_(MPa)'
  endif
  end subroutine

end module
