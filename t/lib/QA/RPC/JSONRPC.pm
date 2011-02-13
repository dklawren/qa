# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::RPC::JSONRPC;
use strict;
use base qw(QA::RPC JSON::RPC::Client);

use URI::Escape;

use constant DATETIME_REGEX => qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;
sub TYPE {
    my ($self) = @_;
    return $self->bz_get_mode ? 'JSON-RPC GET' : 'JSON-RPC';
}

#################################
# Consistency with XMLRPC::Lite #
#################################

sub ua {
    my $self = shift;
    if ($self->{ua} and not $self->{ua}->isa('QA::RPC::UserAgent')) {
        bless $self->{ua}, 'QA::RPC::UserAgent';
    }
    return $self->SUPER::ua(@_);
}
sub transport { $_[0]->ua }

sub bz_get_mode {
    my ($self, $value) = @_;
    $self->{bz_get_mode} = $value if @_ > 1;
    return $self->{bz_get_mode};
}

sub _bz_callback {
    my ($self, $value) = @_;
    $self->{bz_callback} = $value if @_ > 1;
    return $self->{bz_callback};
}

sub call {
    my $self = shift;
    my ($method, $args) = @_;
    my %params = ( method => $method, params => [$args] );
    my $config = $self->bz_config;
    my $url = $config->{browser_url} . "/"
              . $config->{bugzilla_installation} . "/jsonrpc.cgi";
    my $result;
    if ($self->bz_get_mode) {
        my $method_escaped = uri_escape($method);
        $url .= "?method=$method_escaped";
        if (my $cred = $self->_bz_credentials) {
            $args->{Bugzilla_login} = $cred->{user}
                if !exists $args->{Bugzilla_login};
            $args->{Bugzilla_password} = $cred->{pass}
                if !exists $args->{Bugzilla_password};
        }
        if ($args) {
            my $params_json = $self->json->encode($args);
            my $params_escaped = uri_escape($params_json);
            $url .= "&params=$params_escaped";
        }
        if ($self->version eq '1.1') {
            $url .= "&version=1.1";
        }
        my $callback = delete $args->{callback};
        if (defined $callback) {
            $self->_bz_callback($callback);
            $url .= "&callback=" . uri_escape($callback);
        }
        $result = $self->SUPER::call($url);
    }
    else {
        $result = $self->SUPER::call($url, \%params);
    }

    if ($result) {
        bless $result, 'QA::RPC::JSONRPC::ReturnObject';
    }
    return $result;
}

sub _get {
    my $self = shift;
    my $result = $self->SUPER::_get(@_);
    # Simple JSONP support for tests. We just remove the callback from
    # the return value.
    my $callback = $self->_bz_callback;
    if (defined $callback and $result->is_success) {
        my $content = $result->content;
        $content =~ s/^\Q$callback(\E(.*)\)$/$1/s;
        $result->content($content);
        # We don't need this anymore, and we don't want it to affect
        # future calls.
        delete $self->{bz_callback};
    }
    return $result;
}

1;

package QA::RPC::JSONRPC::ReturnObject;
use strict;
use JSON::RPC::Client;
use base qw(JSON::RPC::ReturnObject);

#################################
# Consistency with XMLRPC::Lite #
#################################

sub faultstring { $_[0]->{content}->{error}->{message} }
sub faultcode   { $_[0]->{content}->{error}->{code}    }
sub fault { $_[0]->is_error }

1;

package QA::RPC::UserAgent;
use strict;
use base qw(LWP::UserAgent);

########################################
# Consistency with XMLRPC::Lite's ->ua #
########################################

sub send_request {
    my $self = shift;
    my $response = $self->SUPER::send_request(@_);
    $self->http_response($response);
    return $response;
}

# Copied directly from SOAP::Lite::Transport::HTTP.
sub http_response {
    my $self = shift;
    if (@_) { $self->{'_http_response'} = shift; return $self }
    return $self->{'_http_response'};
}