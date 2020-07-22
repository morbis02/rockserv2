# Very temporary replacement for Dillfrog::Mail
# Quite incomplete right now
# Initial version by EnsignYu on 31 Dec 2004

use strict;
package Dillfrog::Mail;

sub new {
    my $proto = shift;
    my $self = {};
    bless($self, $proto);
    return $self;
}

sub get_inbox_count_by_uin {
    my ($self, $uin) = @_;

    # Returns the number of messages a $uin has stored in their "To" box

    # TODO: Return the actual number :-)
    return 0;
}

sub send_local_mail {
    my ($self, %kvpairs) = @_;

    # TODO: Sends a local (same-server) message to some user.
    # the kvpairs hash contains all the interesting stuff.

    # Plat can provide examples and more info about the %kvpairs hash if
    # you decide to expand this code.

    # is_spam:      Y or N based on spam-detection code
    # from_trusted: Y or N (if the user was authed in when sending the message, they're trusted; unsigned smtp mail is untrusted)
    # to_group: a group ID (e.g. 34) or arrayref of these, not related to Rockserv groups. E.g. "Superfrog" is a group at dillfrog.com
    # to_uin: a UIN (e.g. 1) or arrayref of these
    # transport_type
    # subject
    # body
    # from_uin
    # from_email
    # from_label: the label of the person who sent it (e.g. "Kaine Da Banker")
    # headers
    # from_ip
    
    # We return 1 for success, 0 on failure
    return 1;
}

sub clear_all_inbox_messages_by_uin {
    my ($self, $uin, $option_hash) = @_;

    # TODO: Delete all messages stored for this UIN
    #       (currently no options are passed through the option hash)
}

sub get_inbox_oldest_message_by_uin {
    my ($self, $uin, $option_hash) = @_;
}

1;
