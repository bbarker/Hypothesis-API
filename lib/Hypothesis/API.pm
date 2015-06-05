package Hypothesis::API;

use 5.006;
use strict;
use warnings;

#use Attribute::Generator;
use namespace::autoclean;
use Moose;
use Storable qw( dclone );

use CGI::Cookie;
use HTTP::Cookies;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use URI;
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

# my $uri_encoder = URI::Encode->new( { 
#     encode_reserved => 0, 
#     double_encode => 0, 
# } );

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

has 'uri_encoder' => (
    is        => 'ro',
    default   =>  sub {  
        URI::Encode->new( { 
            encode_reserved => 0, 
            double_encode => 0, 
        } );
    },
    predicate => 'has_uri_encoder',
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
        return $class->$orig( username => $_[0], password => undef );
    } else {
        return $class->$orig( username => undef, password => undef );
    }
};

=head1 SUBROUTINES/METHODS

=head2 create($payload)

Generalized interface to POST /api/annotations

In the simplest form, creates an annotation
$payload->{'text'} at $payload->{'uri'}.
For more sophisticated usage please see the
hypothes.is API documentation.

Returns annotation id if created or HTTP status 
code otherwise.

=cut

sub create {
    my ($self, $payload) = @_;

    if (ref($payload) ne "HASH") {
        warn('payload is not a hashref');
        return -1;
    }
    if (not exists $payload->{'uri'}) {
        warn("payload does not contain a 'uri' key to be annotated");
        return -1;
    }
    my $payload_out = dclone $payload;
    my $user = $self->username;
    my $user_acct = "acct:$user\@hypothes.is";
    print $user_acct . "\n";
    $payload_out->{'user'} = $user_acct;
    if (not exists $payload->{'permissions'}) {
        $payload_out->{'permissions'} = { 
            "read"   => ["group:__world__"],
            "update" => [$user_acct],
            "delete" => [$user_acct],
            "admin"  => [$user_acct]
        };
    }
    if (not exists $payload->{'document'}) {
        $payload_out->{'document'} = {};
    }
    if (not exists $payload->{'text'}) {
        $payload_out->{'text'} = undef;
    }
    if (not exists $payload->{'tags'}) {
        $payload_out->{'tags'} = undef;
    }
    if (not exists $payload->{'target'}) {
        $payload_out->{'target'} = {
            "selector" => [
                {
                "start" => undef,
                "end"   => undef,
                "type"  => "TextPositionSelector"
                },  
                {
                "type"   => "TextQuoteSelector", 
                "prefix" => undef,
                "exact"  => undef,
                "suffix" => undef
                },
            ]
        };
    }
    
    my $data = $json->encode($payload_out);
    my $h = HTTP::Headers->new;
    $h->header(
        'content-type' => 'application/json;charset=UTF-8', 
        'x-csrf-token' => $self->csrf_token,
        'X-Annotator-Auth-Token' => $self->token, 
    );
    $self->ua->default_headers( $h );
    my $url = URI->new( "${\$self->api_url}/annotations" );
    my $response = $self->ua->post( $url, Content => $data );
    if ($response->code == 200) {
        #print Dumper($response->content);
        my $json_content = $json->decode($response->content);
        if (exists $json_content->{'id'}) {
            return $json_content->{'id'};
        } else {
            return -1;
        }
    } else {
        return $response->code;
    }
}


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
    my $url = URI->new( "${\$self->api_url}/token" );
    $url->query_form(assertion => $self->csrf_token);
    $response = $self->ua->get( $url );
    $self->token($response->content);

    return 0;
}

=head2 search(query)

Generalized interface to GET /api/search

Generalized query function.

query is a hash ref with the following optional keys 
as define din the hypothes.is HTTP API:
 * limit
 * offset
 * uri
 * text
 * quote
 * user

=cut

#FIXME: need to implement some form of recursion
#to scan over multiple pages (probably as a generator)
sub search {
    my ($self, $query) = @_;

    my $h = HTTP::Headers->new;
    $h->header(
        'content-type' => 'application/json;charset=UTF-8', 
        'x-csrf-token' => $self->csrf_token,
    );
    if ( defined $query->{ 'uri' } ) {
        $query->{ 'uri' } = $self->uri_encoder->encode(
            $query->{ 'uri' }
        );
    }

    my $url = URI->new( "${\$self->api_url}/search" );
    $url->query_form($query);
    my $response;
    my $json_content;
    do {
        $response = $self->ua->get( $url );
        #$json_content = $json->decode($response->content);
        #DEBUG:
        print $response->content;
    } while (length $json_content->{ 'rows' } > 0);

}

=head1 AUTHOR

Brandon E. Barker, C<< <brandon.barker at cornell.edu> >>

Created  06/2015

Licensed under the Apache License, Version 2.0 (the "Apache License");
also licensed under the Artistic License 2.0 (the "Artistic License").
you may not use this file except in compliance with one of
these two licenses. You may obtain a copy of the Apache License at

    http://www.apache.org/licenses/LICENSE-2.0

Alternatively a copy of the Apache License should be available in the
LICENSE-2.0.txt file found in this source code repository.

You may obtain a copy of the Artistic License at

    http://www.perlfoundation.org/artistic_license_2_0

Alternatively a copy of the Artistic License should be available in the
artistic-2_0.txt file found in this source code repository.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the Apache License or Artistic License for the specific language 
governing permissions and limitations under the licenses.

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
