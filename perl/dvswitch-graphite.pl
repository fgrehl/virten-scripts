#!/usr/bin/perl -w
# Author: Florian Grehl - www.virten.net
#
# Description: 
# Sends VMware Distributed Switch Port statistics to a Carbon Cache Relay to 
# create graphs with Graphite. Target can be a vCenter Server or ESXi Host. 
# Running this script against a vCenter requires triggering "Refresh dvPort state" 
# 

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use IO::Socket::INET;
use Data::Dumper;

my $vcServer     = 'vcenter.virten.lab';
my $vcUser       = 'admin';
my $vcPass       = 'password';
my $carbonServer = 'graphite.virten.lab';
my $carbonPort   = 2003;
my $debug        = 0;

my $time = time();

# Connect to vCenter Server
Opts::set_option('server', $vcServer);
Opts::set_option('username', $vcUser);
Opts::set_option('password', $vcPass);
Opts::parse();
Opts::validate();
print "Connecting to " . $vcServer . "...\n" if $debug;
Util::connect();
my $sc = Vim::get_service_content();
my $vCenterVersion = $sc->about->version;
print "Connected to " . $vcServer . " (" . $sc->about->fullName . ")\n" if $debug;

# Connect to Carbon Cache Relay 
my $sock = new IO::Socket::INET( PeerAddr => $carbonServer, PeerPort => $carbonPort, Proto => 'tcp') unless $debug;
$sock or die "no socket: $!" unless $debug;

my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch');
foreach my $dvs (@$dvSwitches){
  print "Processing dvSwitch: ".$dvs->name."...\n" if $debug;
  
  # Refresh Portstate - Required when pulling statistics from vCenter Server 
  if ($sc->about->apiType eq 'VirtualCenter'){
    print "Refreshing port states...\n" if $debug;
    my $dportState = $dvs->RefreshDVPortState;
  }  
  
  my $dvsName = $dvs->name;
  $dvsName =~ tr/[. ]/_/;
  my $prefix = "vcenter.network." . $dvsName . ".";
  my $dvsCriteria = DistributedVirtualSwitchPortCriteria->new(connected => 'true');
	my $dvPorts = $dvs->FetchDVPorts(criteria => $dvsCriteria);
  
  foreach my $dvport (@$dvPorts) {
    eval{
      my $connectee;
      if ($dvport->connectee->connectedEntity->type eq 'HostSystem'){
        my $connectedEntity = Vim::get_view(mo_ref => $dvport->connectee->connectedEntity);
        $connectee = $connectedEntity->name."_".$dvport->connectee->nicKey;
      } else {
        $connectee = $dvport->state->runtimeInfo->linkPeer;
      } 
       
      if ($connectee){
        $connectee =~ tr/[. ]/_/;
        sendMetric($prefix.$connectee.".bytesInBroadcast ".$dvport->state->stats->bytesInBroadcast);
        sendMetric($prefix.$connectee.".bytesInMulticast ".$dvport->state->stats->bytesInMulticast);
        sendMetric($prefix.$connectee.".bytesInUnicast ".$dvport->state->stats->bytesInUnicast);
        sendMetric($prefix.$connectee.".bytesOutBroadcast ".$dvport->state->stats->bytesOutBroadcast);
        sendMetric($prefix.$connectee.".bytesOutMulticast ".$dvport->state->stats->bytesOutMulticast);
        sendMetric($prefix.$connectee.".bytesOutUnicast ".$dvport->state->stats->bytesOutUnicast);
        sendMetric($prefix.$connectee.".packetsInBroadcast ".$dvport->state->stats->packetsInBroadcast);
        sendMetric($prefix.$connectee.".packetsInDropped ".$dvport->state->stats->packetsInDropped);
        sendMetric($prefix.$connectee.".packetsInException ".$dvport->state->stats->packetsInException);
        sendMetric($prefix.$connectee.".packetsInMulticast ".$dvport->state->stats->packetsInMulticast);
        sendMetric($prefix.$connectee.".packetsInUnicast ".$dvport->state->stats->packetsInUnicast);
        sendMetric($prefix.$connectee.".packetsOutBroadcast ".$dvport->state->stats->packetsOutBroadcast);
        sendMetric($prefix.$connectee.".packetsOutDropped ".$dvport->state->stats->packetsOutDropped);
        sendMetric($prefix.$connectee.".packetsOutException ".$dvport->state->stats->packetsOutException);
        sendMetric($prefix.$connectee.".packetsOutMulticast ".$dvport->state->stats->packetsOutMulticast);
        sendMetric($prefix.$connectee.".packetsOutUnicast ".$dvport->state->stats->packetsOutUnicast);
      }
    }
  }
}

Util::disconnect();

# Functions
sub sendMetric {
  my $metric = $_[0];
  print $metric." ".$time."\n" if $debug;
  $sock->send($metric." ".$time."\n") unless $debug;
}
