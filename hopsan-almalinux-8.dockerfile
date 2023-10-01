FROM almalinux:8

RUN dnf update -y

RUN dnf install 'dnf-command(config-manager)' -y
RUN dnf config-manager --enable powertools

RUN dnf groupinstall "Development Tools" -y
RUN dnf install doxygen python3 -y

RUN dnf install qt5-qtbase-devel qt5-qtbase-private-devel qt5-qtsvg-devel qt5-qtwebchannel-devel -y
