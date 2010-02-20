package Path::StepDispatcher;

use strict;
use warnings;

use Any::Moose;
use Path::StepDispatcher::Carp;

has build_context =>
    qw/ accessor _build_context default Path::StepDispatcher::Context /;

has build_switch_context =>
    qw/ accessor _build_switch_context default Path::StepDispatcher::SwitchContext /;

has build_match =>
    qw/ accessor _build_match default Path::StepDispatcher::Match /;

has root => qw/ is rw required 1 isa Path::StepDispatcher::Switch /;

has visitor => qw/ is ro required 1 isa CodeRef /; 

sub dispatch {
    my $self = shift;
    my %given;
    if ( @_ == 1 ) {
        %given = ( path => shift );
    }
    else {
        %given = @_;
    }

    my $path = $given{path};
    my $ctx = $self->build_context( dispatcher => $self, path => $path, visitor => $self->visitor );
    $self->root->dispatch( $ctx );
}

sub build_context {
    my $self = shift;
    return $self->_build( $self->_build_context, @_ );
}

sub build_switch_context {
    my $self = shift;
    return $self->_build( $self->_build_switch_context, @_ );
}

sub build_match {
    my $self = shift;
    return $self->_build( $self->_build_match, @_ );
}

sub _build {
    my $self = shift;
    my $builder = shift;

    if ( ref $builder eq 'CODE' ) {
        return $builder->( @_ );
    }
    elsif ( $builder && ref $builder eq '' ) {
        $builder->new( @_ ); # TODO Wrap this?
    }
    else {
        croak "Do not know how to builder with ($builder)";
    }
}

package Path::StepDispatcher::Context;

use Any::Moose;

has dispatcher => qw/ is ro required 1 isa Path::StepDispatcher /;
has visitor => qw/ is ro required 1 isa CodeRef /; 
has path => qw/ is rw isa Str /;
#has target_path => qw/ is rw isa Maybe[Str] /;
has leftover_path => qw/ is rw isa Maybe[Str] /;

sub visit {
    my ( $self, $data, $item ) = @_;
    $self->visitor->( $self, $data, $item );
}

package Path::StepDispatcher::SwitchContext;

use Any::Moose;

has context => qw/ is ro required 1 isa Path::StepDispatcher::Context /;

package Path::StepDispatcher::Match;

use Any::Moose;

has target_path => qw/ is ro required 1 isa Str /;
has leftover_path => qw/ is ro required 1 isa Str /;
has match_path => qw/ is ro isa Str lazy_build 1 /;
sub _build_match_path {
    my $self = shift;
    return substr $self->target_path, 0, length $self->leftover_path;
}
has match_arguments => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

package Path::StepDispatcher::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 isa Regexp /;

sub match {
    my $self = shift;
    my $path = shift;

    return unless my @arguments = ( $path =~ $self->regexp );
    my $leftover_path = eval q{$'};

    undef @arguments unless defined $1; # Just got the success indicator

    return {
        leftover_path => $leftover_path,
        match_arguments => \@arguments,
    };
}

package Path::StepDispatcher::Switch;

use Any::Moose;

has rule => qw/ is ro /;
has sequence => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

sub add {
    my $self = shift;
    my $node = shift;

    push @{ $self->sequence }, $node;

    return $node;
}

sub dispatch {
    my $self = shift;
    my $ctx = shift;

    my $match;
    if ( my $rule = $self->rule ) {
        my $path = $ctx->path;
        return unless $match = $rule->match( $path );
        $match = $ctx->dispatcher->build_match( %$match, target_path => $path );
        $ctx->path( $match->leftover_path );
    }

    for my $node (@{ $self->sequence }) {
        $node->dispatch( $ctx );
    }
}

package Path::StepDispatcher::Item;

use Any::Moose;

has data => qw/ is ro /;

sub dispatch {
    my $self = shift;
    my $ctx = shift;
    $ctx->visit( $self->data, $self );
}

use Any::Moose;

package Path::StepDispatcher::Builder;

use Any::Moose;
use Path::StepDispatcher::Carp;

has $_ => ( accessor => "_$_" )
    for qw/ parse_rule parse_item build_switch /;

sub parse_rule {
    my $self = shift;
    my $input = shift;

    my $rule;

    $rule = $self->_parse( $self->_parse_rule, $input );
    return $rule if defined $rule; # TODO Check if $rule does Rule

    $rule = $self->builtin_parse_rule( $input );
    return $rule if defined $rule;

    croak "Unable to parse rule ($input)";
}

sub builtin_parse_rule {
    my $self = shift;
    my $input = shift;

    if ( ref $input eq 'Regexp' ) {
        return Path::StepDispatcher::Rule::Regexp->new( regexp => $input );
    }

    return undef;
}

sub parse_item {
    my $self = shift;
    return $self->_parse( $self->_parse_item, @_ );
}

sub build_switch {
    my $self = shift;
    return $self->_build( $self->_build_switch, @_ );
}

sub _parse {
    my $self = shift;
    my $parser = shift;

    if ( ref $parser eq 'CODE' ) {
        return $parser->( @_ );
    }
    else {
        croak "Do not know how to parse with ($parser)";
    }
}

sub _build {
    my $self = shift;
    my $builder = shift;

    if ( ref $builder eq 'CODE' ) {
        return $builder->( @_ );
    }
    elsif ( $builder && ref $builder eq '' ) {
        $builder->new( @_ ); # TODO Wrap this?
    }
    else {
        croak "Do not know how to builder with ($builder)";
    }
}

1;
