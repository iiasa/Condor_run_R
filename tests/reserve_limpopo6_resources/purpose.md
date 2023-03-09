Reserve resources on limpopo6 for interactive use
beyond the 50GB of memory that is already by
default set aside for interactive use.

Edit `reserve.job` to specify the resource types
and amounts to reserve. Then submit the job via
`reserve.sh` (Linux/MacOS) or `reserve.bat`
(Windows). This reserves the resources on limpopo6
until the job stops running. The job runs the
script `job.bat` on limpopo6 which by default
will sleep for 10 days before timing out.

Use `condor_q` to see if the job is going from
the idle to the running state, or check the
`reserve.log` and `reserve.err` files to make
sure that no errors occured. A likely issue is
that the resources are not available at the
moment of submission, and hence the job remains
in the idle (queued) state.

To release the reserved resources early, remove
the job by issuing
```
condor_rm <cluster number>
```
or
```
condor_rm <your user name>
```

Beware that the latter will remove **all** your
jobs and thus should not be used when you have
other jobs running.

To view the available resources on limpopo6, run the
`avail.sh` (Linux/MacOS)` or `avail.bat` (Windows)
script. Doing so before and after submitting the
reserve job should show a reduction of available
resources matching what you configured in
`reserve.job`

If you want the reservation to time out earlier,
edit `sleep.bat`. In addition to days (`d`) you
can also use hourse (`h`) or minutes (`m`) or
seconds (`s`) as units of time appended to the
number.
