package Path::Walker;

use strict;
use warnings;

package Path::Walker::Walker;

use Any::Moose;

use Try::Tiny;

has dispatcher => qw/ is ro required 1 /;

has path => qw/ accessor initial_path required 1 isa Str /;
has root => qw/ is ro required 1 /;

has sequence => qw/ is ro isa ArrayRef /, default => sub { [] };
has _step => qw/ is rw /;

has visitor => qw/ is rw isa CodeRef /;

sub BUILD {
    my $self = shift;
    $self->push( route => $self->root, leftover => $self->initial_path );
}

sub walk {
    my $self = shift;
    $self->walk_route( $self->root );
}

sub walk_route {
    my $self = shift;
    my $route = shift;

    $self->visit( $route->before ) if $route->before;

    for my $child ( $route->children ) {
        if ( blessed $child ) { # && $child->does( 'Route' )
            last if $self->visit_route( $child );
        }
        else {
            $self->visit( $child );
        }
    }

    $self->visit( $route->after ) if $route->after;

    $self->visit( $route->end ) if $route->end;
}

sub visit {
    my $self = shift;
    my $data = shift;

    $self->dispatcher->visit( $self->visitor, data => $data );
}

sub visit_route {
    my $self = shift;
    my $route = shift;

    return 0 unless $self->consume( $route ); # Does a push

    my $error;
    try { $self->walk_route( $route ) } catch { $error = $_ };
    $self->pop;
    die $error if $error;

    return 1;
}

sub consume {
    my $self = shift;
    my $next_route = shift;

    my $last_step = $self->step;
    my $path = $last_step->leftover;
    my $rule = $next_route->rule;
    
    return 0 unless my $match = $rule->match( $path );

    {
        my $leftover = $match->{leftover};
        my $segment = substr $path, 0, -1 * length $leftover;
        my $prefix = $last_step->prefix . $last_step->segment;

        $self->push(
            match => $match,
            segment => $segment,
            prefix => $prefix,
            leftover => $leftover,
            route => $next_route,
        );
    }

    return 1;
}

sub push {
    my $self = shift;
    my $step = $self->dispatcher->build_step( @_ );
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

# Control: ->return, ->halt, ->next

package Path::Walker::Step;

use Any::Moose;

has route => qw/ is ro required 1 /;
has [qw/ prefix leftover segment /] => qw/ is ro isa Str /, default => '';
has captured => qw/ is ro isa ArrayRef /, default => sub { [] };

package Path::Walker::Route;

use Any::Moose;

has rule => qw/ is ro required 1 /;
has children => qw/ accessor _children isa ArrayRef /, default => sub { [] };
sub children { return @{ shift->_children } }
has [qw/ before after end /] => qw/ is rw isa Maybe[CodeRef] /;

sub add {
    my $self = shift;
    push @{ $self->_children }, @_;
}

package Path::Walker::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 isa Regexp /;
has _regexp => qw/ is ro lazy_build 1 /;

sub _build__regexp {
    my $self = shift;
    my $regexp = $self->regexp;

    # TODO This is done because of issues with $'
    # Also because it seems to be the sane thing you would want to do
    # (Not match a branching action in the middle)
    # What about leading space, delimiter garbage, etc.?

    $regexp = qr/^$regexp/;
    return $regexp;
}

sub regexp_match {
    my $self = shift;
    my $path = shift;
    my $regexp = shift;

    return unless my @arguments = $path =~ $regexp;
    my $leftover_path = eval q{$'};

    undef @arguments unless defined $1; # Just got the success indicator

    return {
        leftover => $leftover_path,
        arguments => \@arguments,
    };
}

sub match {
    my $self = shift;
    my $path = shift;

    return $self->regexp_match( $path, $self->_regexp );
}

package Path::Walker::Rule::SlashPattern;

use Any::Moose;

has pattern => qw/ is ro required 1 isa Str/;
has regexp => qw/ is ro lazy_build 1 /;
sub _build_regexp {
    my $self = shift;
    return $self->parse( $self->pattern );
}

sub parse {
    my $self = shift;
    my $pattern = shift;

    # Adapted from Dancer::Route::make_regexp_from_route

    if ( $pattern =~ m/^\d+$/ ) {
        $pattern = "/([^/]+)" x $pattern;
    }
    else {

        $pattern =~ s#/+#/#g;

        # Parse .../*/...
        $pattern =~ s#\*#([^/]+)#g;

        # Escape '.'
        $pattern =~ s#\.#\\.#g;
    }

    $pattern = "^$pattern";

    return qr/$pattern/;
}

sub match {
    my $self = shift;
    my $path = shift;

    return Path::Walker::Rule::Regexp->regexp_match( $path, $self->regexp );
}

package Path::Walker::Rule::Always;

use Any::Moose;

sub match {
    my $self = shift;
    my $path = shift;

    return {
        leftover => $path,
    };
}

1;
