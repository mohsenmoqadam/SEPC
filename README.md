SEPC
=====
SEPC is a bash script which create an `Erlang project`.
Projects that created with SEPC has 4 profiles: `Test`, `Development`, `Stage` and `Production`.
`Test` profile used for Common Test or CT.
`Development` profile used for developing purpose. I use this profile for running project on my PC.
`Stage` profile used for pre deployment. Before I deploy a project on production environment, I deploy it on stage and other staff used it for their purposes.
`Production` profile used for real deployment on production servers.

1-download
-----
Use `git` command for downloading SEPC:

	%git clone https://github.com/mohsenmoqadam/SEPC

2-use the SEPC
-----
go to SEPC directory:

	%cd SEPC
Create your project:

	%./sepc.sh app_name
Or: 

	%./sepc.sh app_name app_ver

3-run project on your PC and enjoy!
-----

	%make proto
	%make rel-dev
	%make console-dev

4-create a tar archive for stage:
-----
	%make rel-stage
take note of the last line, it informs you about `Tarball` path.
You can upload it on stage environment.

5-create a tar archive for production:
-----
	%make rel-prod
take note of the last line, it informs you about `Tarball` path.
You can upload it on production environment.
