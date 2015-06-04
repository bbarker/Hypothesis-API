package Hypothesis::API;

use 5.006;
use strict;
use warnings;

use namespace::autoclean;
use Moose;

use CGI::Cookie;
use HTTP::Cookies;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use URI::Encode;

# For better performance, also install:
# JSON::XS

#DEBUG
use Data::Dumper;

=head1 NAME

Hypothesis::API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

A Perl wrapper for the hypothes.is web (HTTP) API.

    use Hypothesis::API;

    my $H = Hypothesis::API->new();

    # or if user-specific queries are needed:
    my $H = Hypothesis::API->new($username);

    # or if login is needed (usually for annotator-store alterations)
    my $H = Hypothesis::API->new($username, $password);
    $H->login;


=head1 EXPORT

Currently nothing.

=cut

my $json = JSON->new->allow_nonref;
$json->pretty(1);
$json->canonical(1); 

my $uri_encoder = URI::Encode->new( { encode_reserved => 0 } );

has 'api_url' => (
    is        => 'ro',
    default   => 'https://hypothes.is/api',
    predicate => 'has_api_url',
);

has 'app_url' => (
    is        => 'ro',
    default   => 'https://hypothes.is/app',
    predicate => 'has_app_url',
);

has 'username' => (
    is         => 'rw',
    predicate  => 'has_username',
);

has 'password' => (
    is         => 'rw',
    predicate  => 'has_password',
);

has 'token' => (
    is         => 'rw',
    predicate  => 'has_token',
);

has 'csrf_token' => (
    is           => 'rw',
    predicate    => 'has_csrf_token',
);

has 'ua' => (
    is        => 'ro',
    default   =>  sub { LWP::UserAgent->new; },
    predicate => 'has_ua',
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ >= 2 ) {
        if ( @_ > 2) {
            warn("At most two arguments expected in constructor.");
        }
        return $class->$orig( username => $_[0], password => $_[1] );
    } elsif ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( username => $_[0], password => q() );
    } else {
        return $class->$orig( username => q(), password => q() );
    }
};

=head1 SUBROUTINES/METHODS

=head2 login

Proceeds to login; on success retrieves and stores 
CSRF and bearer tokens.

=cut

sub login {
    my ($self) = @_;

    # Grab cookie_jar for csrf_token, etc.
    my $request  = HTTP::Request->new(GET => $self->app_url);  
    my $cookie_jar  = HTTP::Cookies->new();
    $self->ua->cookie_jar($cookie_jar);
    my $response = $self->ua->request($request);
    $cookie_jar->extract_cookies( $response );
    my %cookies = CGI::Cookie->parse($cookie_jar->as_string);
    if (exists $cookies{'Set-Cookie3: XSRF-TOKEN'}) {
        $self->csrf_token($cookies{'Set-Cookie3: XSRF-TOKEN'}->value); 
    } else {
        warn("Login failed: couldn't obtain CSRF token.");
        return -1;
    }

    my $h = HTTP::Headers->new;
    $h->header(
        'content-type' => 'application/json;charset=UTF-8', 
        'x-csrf-token' => $self->csrf_token,
        );
    $self->ua->default_headers( $h );
    my $payload = {
        username => $self->username,
        password => $self->password
    };
    my $data = $json->encode($payload);
    $response = $self->ua->post(
        $self->app_url . '?__formid__=login', 
        Content => $data
    );
    my $url = "${\$self->api_url}/token?assertion=${\$self->csrf_token}";
    my $url = $uri_encoder->encode( $url );
    $response = $self->ua->get( $url );
    $self->token($response->content);

    return 0;
}

=head1 AUTHOR

Brandon E. Barker, C<< <brandon.barker at cornell.edu> >>

Created  06/2015

=head1 BUGS

Please report any bugs or feature requests to C<bug-hypothesis-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Hypothesis-API>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Hypothesis::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Hypothesis-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Hypothesis-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Hypothesis-API>

=item * Search CPAN

L<http://search.cpan.org/dist/Hypothesis-API/>

=back


=head1 ACKNOWLEDGEMENTS

=cut

1; # End of Hypothesis::API
