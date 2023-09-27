FROM almalinux:8

RUN dnf groupinstall "Development Tools" -y

RUN dnf update -y

#RUN dnf install 'dnf-command(config-manager)'
#RUN dnf config-manager --enable powertools

RUN dnf install qt5-qtbase-devel qt5-qtbase-private-devel qt5-qtsvg-devel qt5-qtwebchannel-devel -y
RUN dnf install python3 -y
