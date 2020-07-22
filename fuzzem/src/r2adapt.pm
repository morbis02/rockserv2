# Adaptor for some r3 compatibility

package SimpleChatter;
sub load {
    my ($self, $objid) = @_;
    return $rock::rock->get_pobj($objid);
}

package rock;
$rock::rock = rock->new() unless $rock::rock;
use group_man;
$rock::group_man = group_man->new();

sub new {
   return bless ({}, shift);
}

sub player_objs {
    my $self = shift;
    my @objs;
    foreach my $uid (values(%{$main::activeuids})) {
        my $player = $main::objs->{$uid};
        push(@objs, $player);
    }
    return @objs;
}

sub get_pobj {
    my ($self, $objid) = @_;
    return $main::objs->{$objid} || undef;
}

%rock::genderposmap = ('M' => 'his', 'F' => 'her', 'N' => 'its');  # posession
%rock::genderpromap = ('M' => 'him', 'F' => 'her', 'N' => 'it');   # pronoun
%rock::genderppromap = ('M' => 'he',  'F' => 'she', 'N' => 'it');  # personal pronoun

package rockobj;

sub get_objid { return $_[0]->{'OBJID'}; }
sub get_name { return $_[0]->{'NAME'}; }
sub get_hp_pct { return $_[0]->{'HP'}/$_[0]->{'MAXH'}; }
sub get_gender { my $g = $_[0]->{'GENDER'}; return 'N' unless $g; return $g eq 'male'?'M':'F'; }
sub get_turns { return $_[0]->{'T'}; }
sub is_r3 { return 0; }
sub is_r2 { return 1; }

1;
