#!/usr/bin/perl -w
# Author: Florian Grehl - www.virten.net
#
# Description: 
# Gathers NSX Edge Gateway statistics from the REST API and sends them to a 
# Carbon Cache Relay to create graphs with Graphite. 
#

use strict;
use REST::Client;
use MIME::Base64;
use XML::LibXML;
use IO::Socket::INET;
use Data::Dumper;

# Disable SSL server verification
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0; 

# Configuration
my $nsxUsername  = 'admin';
my $nsxPassword  = 'password';
my $nsxMgt       = 'nsg-manager.virten.lab';
my $prefix       = 'nsx.edge.';
my $carbonServer = 'graphite.virten.lab';
my $carbonPort   = 2003;
my $debug        = 0;
#

# Connect to Carbon Cache Relay 
my $sock = new IO::Socket::INET( PeerAddr => $carbonServer, PeerPort => $carbonPort, Proto => 'tcp') unless $debug;
$sock or die "No socket: $!" unless $debug;

my $client = REST::Client->new();
$client->getUseragent()->ssl_opts( SSL_verify_mode => 0 );
my $headers = {
  "Accept"        => "application/*+xml;version=1.5",
  "Authorization" => 'Basic ' . encode_base64($nsxUsername . ':' . $nsxPassword),
};

foreach my $edge (callNSX("https://".$nsxMgt."/api/4.0/edges/")->findnodes('/pagedEdgeList/edgePage/edgeSummary')) {
  my($edgeId) = $edge->findnodes('./id')->to_literal;
  my($edgeName) = $edge->findnodes('./name')->to_literal;

  my $vnics = {};
  my $dashboard = callNSX("https://".$nsxMgt."/api/4.0/edges/".$edgeId."/statistics/dashboard/interface?interval=1");
  foreach my $vnic ($dashboard->findnodes('/dashboardStatistics/meta/vnics/vnic')) {
    my $index = $vnic->findnodes('./index')->to_literal;
    my $name = $vnic->findnodes('./name')->to_literal;
    $vnics->{$index} = $name->value;
  }

  foreach (sort keys %{$vnics}) {
    my $id = $_;
    my $intInPkt = "vNic__".$id."__in__pkt";
    my $intInByte = "vNic__".$id."__in__byte";
    my $intOutPkt = "vNic__".$id."__out__pkt";
    my $intOutByte = "vNic__".$id."__out__byte";

    foreach my $daStInPkt ($dashboard->findnodes('/dashboardStatistics/data/interfaces/'.$intInPkt.'/dashboardStatistic')) {
      my $timestamp = $daStInPkt->findnodes('./timestamp')->to_literal;
      my $value     = $daStInPkt->findnodes('./value')->to_literal;
      sendMetric($prefix.$edgeName.".interface.".$vnics->{$id}.".pkt_in ".$value." ".$timestamp);
    }

    foreach my $daStInByte ($dashboard->findnodes('/dashboardStatistics/data/interfaces/'.$intInByte.'/dashboardStatistic')) {
      my $timestamp = $daStInByte->findnodes('./timestamp')->to_literal;
      my $value     = $daStInByte->findnodes('./value')->to_literal;
      sendMetric($prefix.$edgeName.".interface.".$vnics->{$id}.".byte_in ".$value." ".$timestamp);
    }

    foreach my $daStOutPkt ($dashboard->findnodes('/dashboardStatistics/data/interfaces/'.$intOutPkt.'/dashboardStatistic')) {
      my $timestamp = $daStOutPkt->findnodes('./timestamp')->to_literal;
      my $value     = $daStOutPkt->findnodes('./value')->to_literal;
      sendMetric($prefix.$edgeName.".interface.".$vnics->{$id}.".pkt_out ".$value." ".$timestamp);
    }

    foreach my $daStOutByte ($dashboard->findnodes('/dashboardStatistics/data/interfaces/'.$intOutByte.'/dashboardStatistic')) {
      my $timestamp = $daStOutByte->findnodes('./timestamp')->to_literal;
      my $value     = $daStOutByte->findnodes('./value')->to_literal;
      sendMetric($prefix.$edgeName.".interface.".$vnics->{$id}.".byte_out ".$value." ".$timestamp);
    }
      
  } 

  my $firewallDashboard = callNSX("https://".$nsxMgt."/api/4.0/edges/".$edgeId."/statistics/dashboard/firewall?interval=1");
  foreach my $fwConnections ($firewallDashboard->findnodes('/dashboardStatistics/data/firewall/connections/dashboardStatistic')) {
    my $timestamp = $fwConnections->findnodes('./timestamp')->to_literal;
    my $value     = $fwConnections->findnodes('./value')->to_literal;
    sendMetric($prefix.$edgeName.".firewall.connections ".$value." ".$timestamp);
  }

  my $loadbalancerDashboard = callNSX("https://".$nsxMgt."/api/4.0/edges/".$edgeId."/statistics/dashboard/loadbalancer?interval=1");

  foreach my $lbSessions ($loadbalancerDashboard->findnodes('/dashboardStatistics/data/loadBalancer/lbSessions/dashboardStatistic')) {
    my $timestamp = $lbSessions->findnodes('./timestamp')->to_literal;
    my $value     = $lbSessions->findnodes('./value')->to_literal;
    sendMetric($prefix.$edgeName.".loadbalancer.lbSessions ".$value." ".$timestamp);
  }
  foreach my $lbHttpReqs ($loadbalancerDashboard->findnodes('/dashboardStatistics/data/loadBalancer/lbHttpReqs/dashboardStatistic')) {
    my $timestamp = $lbHttpReqs->findnodes('./timestamp')->to_literal;
    my $value     = $lbHttpReqs->findnodes('./value')->to_literal;
    sendMetric($prefix.$edgeName.".loadbalancer.lbHttpReqs ".$value." ".$timestamp);
  }
  foreach my $lbBpsIn ($loadbalancerDashboard->findnodes('/dashboardStatistics/data/loadBalancer/lbBpsIn/dashboardStatistic')) {
    my $timestamp = $lbBpsIn->findnodes('./timestamp')->to_literal;
    my $value     = $lbBpsIn->findnodes('./value')->to_literal;
    sendMetric($prefix.$edgeName.".loadbalancer.lbBpsIn ".$value." ".$timestamp);
  }
  foreach my $lbBpsOut ($loadbalancerDashboard->findnodes('/dashboardStatistics/data/loadBalancer/lbBpsOut/dashboardStatistic')) {
    my $timestamp = $lbBpsOut->findnodes('./timestamp')->to_literal;
    my $value     = $lbBpsOut->findnodes('./value')->to_literal;
    sendMetric($prefix.$edgeName.".loadbalancer.lbBpsOut ".$value." ".$timestamp);
  }

}

### Helper Functions ###

# Call NSX REST API and parse XML
sub callNSX{
  $client->GET($_[0],$headers);
  my $parser = XML::LibXML->new();
  my $content = $parser->parse_string($client->responseContent());
  return $content;
}

# Send Metric to Carbon Cache
sub sendMetric {
  my $metric = $_[0];
  print $metric."\n" if $debug;
  $sock->send($metric."\n") unless $debug;
}
