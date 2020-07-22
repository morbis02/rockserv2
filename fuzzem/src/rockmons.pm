1;

package zombie;
@zombie::ISA = qw( npc );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  return($self);
}
