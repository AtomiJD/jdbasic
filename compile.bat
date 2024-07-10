cd %1
cd ..
java -jar prog8compiler.jar -asmlist -target cx16 %1\\jdbasic.p8 -out %1\\c16disc
