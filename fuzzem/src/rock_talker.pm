package rock_talker;
use strict;
use IO::Socket::INET;

sub broadcast {
    # $talker->broadcast($msgkey, $message)
    my $self = shift;
    eval { $self->{'SOCK'}->send("$_[0] $_[1]"); }
}

sub new {
    my $proto = shift;
    my $self = bless ({}, $proto);
    
    $self->connect();
    return $self;
}

sub handle_incoming {
    # add text to input log, catch long input
    $_[0]->{'IN_LOG'} .= $_[1];
    
    #### NOW, Assuming they hit return: 
    my $ret_index;
    print "LOG: [$_[0]->{'IN_LOG'}]\n";
    # for each line, 
    while(($ret_index = index($_[0]->{'IN_LOG'}, "\n")) != -1) {
        # copy first command to $line, minus the return
        my ($code, $msg) = substr($_[0]->{'IN_LOG'}, 0, $ret_index+1) =~ /^([^ ]+) (.+)$/;
        
        # kill the line from the input log, including the return.
        $_[0]->{'IN_LOG'} = substr($_[0]->{'IN_LOG'}, $ret_index+1);
        
        # And snag it for our own
        $_[0]->handle_code($code, $msg);
    }
}

sub handle_code {
    my ($self, $code, $msg) = @_;
    
    # R2-CHANREC(chan) formatted text
    # R2-CHANSND(chan) FROM TEXT
    if($code =~ /^R2-CHANSND\((\d+)\)$/) {
        my $chan = abs int $1;
        
    }
    
}

sub connect {
    my $self = shift;
    
    # create a tcp connection to the specified host and port
    $self->{'SOCK'} = IO::Socket::INET->new(Proto     => "tcp",
                                    PeerAddr  => '127.0.0.1',
                                    PeerPort  => 2332)
           or warn "WARNING: couldn't connect to the talker! $!"; return;

    $self->{'SOCK'}->autoflush(1) if $self->{'SOCK'};
}

1;
