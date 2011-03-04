Life Tutorial Step 2.

In this step of the Life Tutorial, we change the game so that it is multi-
threaded.  When the NaCl module starts up, it spawns a LifeSimulation thread
which runs the dim ticks.  Some locking classes are added, and some internal
state is added to handle things like view size changes in a multi-threaded
environment.
