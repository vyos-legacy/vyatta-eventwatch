#!/usr/bin/perl

use POSIX;
#use File::Pid;
use XML::Simple;
use Getopt::Long;
use Data::Dumper;
use threads;
use threads::shared;
use strict;

### Global variables
my $defaultConfigFile = "/opt/vyatta/etc/event-handler.conf";
my $configFile = undef;
my $fifoDir = "/var/event-handler/";
my $pidFile = "/var/run/event-handler.pid";
my $foreground = undef;
my $debugLevel = 0;
my $version = "0.1";

### Main functions

## Read config file into a hash
sub readConfig {
    my $configFile = shift;
    $configFile = $defaultConfigFile unless defined($configFile);
    die "Could not open config file $configFile" unless -r $configFile;

    my $configRef = XMLin($configFile, ForceArray => ['policy', 'feed', 'event', 'pattern']);
    print Dumper($configRef) if $debugLevel > 1;

    return $configRef;
}

## Handle a feed, intended to run as a thread
sub feed {
    my ($name, $type, $source, $policy) = @_;
    info("Starting thread for feed $name\n");

    debug("Thread for feed $name started with arguments: type $type, source $source\n")
        if $debugLevel > 1;
    my $fifoFile = undef;
    if ($type eq "fifo") {
        $fifoFile = $source;
    } else {
        
    }

    # Open the pipe for both read and write to
    # prevent closing on EOF when backend
    # restarts
    open (FIFO, "+<$fifoFile")
        or die "Couldn't open $fifoFile: $!\n";

    while (<FIFO>) {
        for my $key (keys %{$policy}) {
             foreach my $pattern (@{$policy->{$key}->{'pattern'}}) {
                 if ($_ =~ m/$pattern/) {
                     my $command = $policy->{$key}->{'run'};
                     my $result = system($command);
                     die "Executing $command failed\n" if $result != 0;                     
                     info( qq{Event "$pattern" caught in feed "$name", command "$command" executed} );
                     # We want the command to be executed on first match in each event only
                     last;
                 }
             }
        }
    }
}

sub main {
    my $config = readConfig($configFile);

    my $feeds = $config->{'feeds'}->{'feed'};
    die "No feeds are defined, exiting" unless defined($feeds);

    my $policies = $config->{'policies'}->{'policy'};
    die "No policies are defined, exiting" unless defined($policies);

    # Spawn feeds
    my %threads;
    for my $key (keys %{$feeds}) {
         my $feed = $feeds->{$key};
         next if ($feed->{'disable'} eq "disable");

         my $type = $feed->{'type'};
         die "Type for feed \"$key\" is not defined" unless defined($type);
         die "Wrong type for feed \"$key\", type can be either fifo or command"
             unless ($type eq "fifo" || $type eq "command");

         my $source = $feed->{'source'};
         die "Source for feed $key is not defined" unless defined($source);

         my $policyName = $feed->{'policy'};
         die "Policy for feed $key is not defined" unless defined($policyName);
         my $policy = undef;
         for my $polkey (keys %{$policies}) {
             $policy = $policies->{$polkey} if( $polkey eq $policyName );
         }
         die "Policy $policyName specified for feed $key does not exist" unless defined($policy);
         
         $policy = $policy->{'event'};
         my $thread  = threads->create(\&feed, $key, $type, $source, $policy);
         %threads->{$key} = $thread;
    }

    print Dumper(%threads) if $debugLevel > 1;

    # Main loop
    while () {
        for my $key (keys %threads) {
            my $thread = %threads->{$key};
            if ($thread->is_running()) {
                # Replace with something meaningful
                print "Thread for $key is ok\n";
            }
        }
        sleep(10);
    }
}

### Auxillary functions

## Throw an informational message
sub info {
    my $message = shift;
    if (defined($foreground)) {
        print $message;
    } else {
        # TODO: add syslog writing
    }
}

## Throw a debug message
sub debug {
    my $message = shift;
    if (defined($foreground)) {
        print "Debug: $message";
    } else {
    }
}

## Throw an error message
sub error {
    my $message = shift;
    if (defined($foreground)) {
        print STDERR "$message";
    } else {
        # TODO: Add syslog writing
    }
}

## Show help message and exit
sub displayHelp {
    my $message = "
The Vyatta Event Daemon looks up for patterns in log file or another text stream
and executes user defined scripts mapped to patterns.

Usage: $0 [--no-daemon] [--config /path/to/config]

Options:
--no-daemon                       Run in foreground, put messages to the
                                  standard output.

--config <path to config file>    Use specified config file instead of default.
                                  Default is $defaultConfigFile.

--debug-level <0|1|2>             Specify debug level. Available levels are:
                                  0: No debug information,
                                  1: Basic debug messages,
                                  2: VERY detailed debug information.
                                  Default is 0.

--version                         Print version and exit.

--help                            Show this message and exit.

";

    print $message;
    exit 0;
}

## Show version and exit
sub displayVersion {
    print "Vyatta Event Handler version $version.\n";
    print "Copyright 2012 Vyatta inc.\n";
    exit 0;
}

### Get options and decide what to do

my $help = undef;
my $version = undef;

GetOptions(
    "no-daemon" => \$foreground,
    "config=s"  => \$configFile,
    "debug-level=i" => \$debugLevel,
    "help" => \$help,
    "version" => \$version
);

displayHelp() if defined($help);
displayVersion() if defined($version);

main();

