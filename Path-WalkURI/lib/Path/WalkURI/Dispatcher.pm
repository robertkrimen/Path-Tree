package Path::WalkURI::Dispatcher;

use strict;
use warnings;

use Any::Moose;

#has builder => qw/ is ro lazy_build 1 /;
#    handles => [qw/ build_route build_walker build_step /];
#sub _build_builder {
#    return Path::WalkURI::Dispatcher::Builder->new;
#}

has root => qw/ is ro lazy_build 1 /;
sub _build_root {
    my $self = shift;
    my ( $root ) = $self->parse_route( undef => '' );
    return $root;
}

sub route {
    my $self = shift;

    my @routes = $self->parse_route( $self->root, @_ );
    push @{ $self->root->_children }, @routes;
}

sub dispatch {
    my $self = shift;
    my $path = shift;

    my $walker = $self->build_walker( path => $path, root => $self->root );
    $walker->walk;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;

    my $regexp = $input;
    $regexp = Path::WalkURI::RegexpRule->parse( $regexp ) unless ref $regexp eq 'Regexp';

    return Path::WalkURI::Dispatcher::Rule::Regexp->new( regexp => $regexp );
}

sub parse_route {
    my $self = shift;
    my $parent = shift;

    my @routes;
    while( @_ ) {

        my ( $rule, $code, $do, $before, $after, $children );
        $rule = ref $_[0] eq 'CODE' ? '' : shift;

#warn $rule;

        if ( ref $_[0] eq 'CODE' ) {
            $code = shift;
        }
        elsif ( ref $_[0] eq 'ARRAY' ) {
            $children = shift;
        }
        elsif ( ! @_ ) {
        }
        else {
            die "Do not know how to parse route (@_)";
        }

        if      ( $rule eq '-before' )  { $parent->before( $before ) }
        elsif   ( $rule eq '-after' )   { $parent->after( $after ) }
        else                            { $do = $code }

        $rule = $self->parse_rule( $rule );

        my $route = $self->build_route( rule => $rule );
        $route->do( $do ) if $do;

        if ( $children ) {
            $route->_children( [ $self->parse_route( $route, @$children ) ] ); 
        }

        push @routes, $route;
    }

    return @routes;
}

sub build_route {
    my $self = shift;
    return Path::WalkURI::Dispatcher::Route->new( dispatcher => $self, @_ );
}

sub build_walker {
    my $self = shift;
    return Path::WalkURI::Dispatcher::Walker->new( dispatcher => $self, @_ );
}

sub build_step {
    my $self = shift;
    return Path::WalkURI::Dispatcher::WalkerStep->new( dispatcher => $self, @_ );
}

package Path::WalkURI::Dispatcher::Builder;

use Any::Moose;

package Path::WalkURI::Dispatcher::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 /;

package Path::WalkURI::Dispatcher::Route;

use Any::Moose;

has dispatcher => qw/ is ro required 1 /;
has rule => qw/ is ro required 1 /;
has children => qw/ accessor _children isa ArrayRef /, default => sub { [] };
sub children { return @{ shift->_children } }
has [qw/ do before after /] => qw/ is rw isa Maybe[CodeRef] /;

package Path::WalkURI::Dispatcher::Walker;

use Any::Moose;

use Path::WalkURI;

has dispatcher => qw/ is ro required 1 /;
has path => qw/ accessor initial_path required 1 isa Str /;
has root => qw/ is ro required 1 /;
has sequence => qw/ is ro isa ArrayRef /, default => sub { [] };
has _step => qw/ is rw /;

sub BUILD {
    my $self = shift;
    $self->push( route => $self->root, leftover => Path::WalkURI->normalize_path( $self->initial_path ) );
}

sub walk {
    my $self = shift;

    while (1) {
        last unless $self->consume;
        my $do = $self->step->route->do;
        $do->() if $do;
    }
}

sub consume {
    my $self = shift;

    my $last_step = $self->step;
    my $step;
    for my $route ( $last_step->route->children ) {
        next unless $step = Path::WalkURI->consume( $last_step, $route->rule->regexp );
        $step = $self->push( %$step, route => $route );
        last;
    }

    return $step ? 1 : 0;
}

sub push {
    my $self = shift;
    my $step = $self->dispatcher->build_step(
        dispatcher => $self->dispatcher, @_
    );
    push @{ $self->sequence }, $step;
    $self->_step( $step );
    return $step;
}

sub pop {
    my $self = shift;
    pop @{ $self->sequence };
    $self->_step( $self->sequence->[ -1 ] );
    # TODO Cannot pop off the last one
}

sub step {
    my $self = shift;
    return $self->_step unless @_;
    my $at = shift;
    $at = -1 unless defined $at;
    return $self->sequence->[ $at ];
}

package Path::WalkURI::Dispatcher::WalkerStep;

use Any::Moose;

has route => qw/ is ro required 1 /;
has [qw/ prefix leftover segment /] => qw/ is ro isa Str /, default => '';
has captured => qw/ is ro isa ArrayRef /, default => sub { [] };

1;
