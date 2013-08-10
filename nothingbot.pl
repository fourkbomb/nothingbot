#!/usr/bin/perl
use strict;
use warnings;
use v5.010;
use POE qw(Component::IRC::State);

my $gnick="forkbot";
my $user="bot(){ bot|bot&; }; bot - NOT RUNNING AS ROOT.";
my $srvr="irc.freenode.net";
my $port=6667;
my $prefix='+';


my @channels = qw(##ninjabottest ##ncss_challenge);

my $irc = POE::Component::IRC::State->spawn(
	nick => $gnick,
	server => $srvr,
	port => $port,
	ircname => $user,
	username=>"uid2"
	
) or die "Failed to connect: $!";

POE::Session->create(
	package_states => [
		main => [ qw(_default _start irc_001 irc_public) ],
	],
	heap => { irc => $irc }
);

$poe_kernel->run();

my @memory = ();

my %lastmessages = ();

our $AWAY = undef;

sub _start {
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	my $irc_session = $heap->{irc}->session_id();
	$kernel->post($irc_session => register => 'all');
	$kernel->post($irc_session => connect => {} );
	return;
}

sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: ");
	for my $arg (@$args) {
		if (ref $arg eq 'ARRAY') {
			push(@output, '[' . join(', ', @$arg) . ']');
		}
		else {
			push @output, $arg;
		}
	}
	print join(' ', @output), "\n";
	return 0;
}

sub irc_001 {
	my ($kernel, $sender) = @_[KERNEL, SENDER];
	my $poco = $sender->get_heap(); #POE::Component object
	print "Connected to ", $poco->server_name(), "\n";
	$kernel->post( $sender => join => $_ ) for @channels;
	return;
}
sub irc_public {
	my ($kernel, $sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0..ARG2];
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $poco = $sender->get_heap();
	print "$nick ($chan): '$what'\n";
	if (defined $AWAY and $what !~ /^\Q${prefix}\Ecomeback/) {
		return;
	}
	
	if ($what =~ /^$gnick/ and $what =~ /(hello)|(hi)|(wassup)|(hey)/) {
		print "PRIVMSG $chan Hey there, $nick\n";
		$kernel->post( $sender => privmsg => $chan => "Hey there, $nick" );
	}
	elsif ($what =~ /^$gnick help/) {
		$kernel->post( $sender => privmsg => $chan => "Say hi to me, and I'll say hi back." );
	}
	elsif ($what =~ /^s\/.*\/.*\/$/) {
		my $newmsg = $lastmessages{$nick};
		eval "\$newmsg =~ $what";
		if ($?) {
			$kernel->post($sender => privmsg => $chan => "Invalid RE.");
			return;
		}
		$lastmessages{$nick} = $newmsg;
		$kernel->post($sender => privmsg => $chan => "$nick meant $newmsg");
	}

	elsif ($what =~ /^$gnick.*, ok\?/) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//g;
		$msg =~ s/, ok\?$//g;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you/ me /ig;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('(s)|(re))? (is)|(are) //ig;
		chomp $msg;
		$msg =~ s/^ +//;
		if (grep(/^$msg/, @memory)) {
			$kernel->post( $sender=>privmsg=>$chan=>"I already know that. Sorry.");
			return;
		}	
		print "MEM: $msg\n";
		push @memory, $msg;
		$kernel->post( $sender => privmsg => $chan => "FYI, $nick, $msg." );
	}
	elsif ($what =~ /^$gnick/) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you / me /ig;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('s)? (is)|(are) //ig;
		chomp $msg;
		print "REQ: $msg\n";
		$msg =~ s/^ +//;
		if ($msg =~ /^is m(y|e)/) {
			my $noun = (split/ /, $msg, 3)[2];
			$msg =~ s/is (m(y|e)) .*$/$1 $noun is/;
		}
		$msg =~ s/[^\w\d]$//;
		if (grep(/^$msg/, @memory)) {
			$kernel->post($sender => privmsg => $chan => "$nick: " . (grep(/^$msg/, @memory))[0]);
		}
		else {
			$kernel->post($sender => privmsg => $chan => "$nick: i'm clueless about $msg.");
		}
	}

	if ($what =~ /^\Q$prefix\E/) {
		$what =~ s/^\Q$prefix\E//;
		my ($cmd,@args) = split/ /,$what;
		given (lc $cmd) {
			when (/^shoo/) {
				$AWAY = 1;
				$kernel->post($sender => privmsg => $chan => "$nick: your wish is my command.");
				$kernel->post($sender => away => "$nick told me to go away.");
			}
			when (/^comeback/) {
				undef $AWAY;
				$kernel->post($sender => "away");
				$kernel->post($sender => privmsg => $chan => "$nick asked me to come back, so i did.");
			}
			when (/^act/) {
				if ($args[0] eq 'be') {
					$args[0] = 'is';
				}
				else {
					$args[0] .= 's';
				}
				
				$irc->yield(ctcp => $chan => "ACTION " . join(' ', @args));
			}
		}
	}
	if ($what !~ /^$gnick/ and $what !~ /^\Q$prefix\E/) {
		$lastmessages{$nick} = $what;
	}
}
