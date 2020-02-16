FROM arcturusnetworks/devenv:latest

RUN echo "Verifying examples can be built"\
 && cd $HOME/examples\
 && mkdir build && cd build && cmake ..\
 && make -j4\
 && ls -1 objdet\
 && ls -1 embed\
 && ls -1 reid\
 && echo "OK"
