package Path::TreeDispatcher;

use strict;
use warnings;

use Any::Moose;
use Path::TreeDispatcher::Carp;

has build_context =>
    qw/ accessor _build_context default Path::TreeDispatcher::Context /;

has build_local_context =>
    qw/ accessor _build_local_context default Path::TreeDispatcher::LocalContext /;

has build_match =>
    qw/ accessor _build_match default Path::TreeDispatcher::Match /;

has root => qw/ is rw required 1/;

has visitor => qw/ is ro required 1 isa CodeRef /,
    default => sub { my $self = shift; sub { $self->builtin_visit( @_ ) } };

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

sub builtin_visit {
    my $self = shift;
    my $ctx = shift;
    my $data = shift;

    if ( ref $data eq 'CODE' ) {
        $data->( $ctx );
    }
    else {
        $data = "undef" unless defined $data;
        croak "Do not know how to visit data ($data)";
    }
}

# $dispatcher->build_context( ... )
# $build->( $dispatcher, ... )
sub build_context {
    my $self = shift;
    return $self->_build( $self->_build_context, @_ );
}

# $dispatcher->build_local_context( ... )
# $build->( $dispatcher, ... )
sub build_local_context {
    my $self = shift;
    return $self->_build( $self->_build_local_context, @_ );
}

# $dispatcher->build_match( ... )
# $build->( $dispatcher, ... )
sub build_match {
    my $self = shift;
    return $self->_build( $self->_build_match, @_ );
}

sub _build {
    my $self = shift;
    my $build = shift;

    if ( ref $build eq 'CODE' ) {
        return $build->( $self, @_ );
    }
    elsif ( $build && ref $build eq '' ) {
        $build->new( @_ );
    }
    else {
        croak "Do not know how to build with $build";
    }
}

package Path::TreeDispatcher::Context;

use Any::Moose;

has dispatcher => qw/ is ro required 1 isa Path::TreeDispatcher /;
has visitor => qw/ is ro required 1 isa CodeRef /; 
has stack => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };
has path => qw/ accessor target_path isa Str /;

sub path {
    my $self = shift;
    if ( my $local = $self->local ) {
        return $local->path( @_ );
    }
    return $self->target_path( @_ );
}

sub local {
    return shift->stack->[-1];
}

sub visit {
    my ( $self, $data ) = @_;
    $self->visitor->( $self, $data );
}

sub push {
    my $self = shift;
    push @{ $self->stack }, $self->dispatcher->build_local_context( context => $self, @_ );
}

sub pop {
    my $self = shift;
    pop @{ $self->stack };
}

package Path::TreeDispatcher::LocalContext;

use Any::Moose;

has context => qw/ is ro required 1 isa Path::TreeDispatcher::Context /;
has match => qw/ is ro required 1 isa Path::TreeDispatcher::Match /;
has path => qw/ is rw isa Str lazy_build 1 /;
sub _build_path {
    my $self = shift;
    return $self->match->leftover_path;
}

package Path::TreeDispatcher::Match;

use Any::Moose;

has target_path => qw/ is ro required 1 isa Str /;
has leftover_path => qw/ is ro required 1 isa Str /;
has match_path => qw/ is ro isa Str lazy_build 1 /;
sub _build_match_path {
    my $self = shift;
    return substr $self->target_path, 0, length $self->leftover_path;
}
has match_arguments => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

package Path::TreeDispatcher::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 isa Regexp /;

sub match {
    my $self = shift;
    my $path = shift;

    # TODO This is done because of issues with $'
    # Also because it seems to be the sane thing you would want to do
    # (Not match a branching action in the middle)
    # What about leading space, delimiter garbage, etc.?
    my $regexp = $self->regexp;
    $regexp = qr/^$regexp/;

    return unless my @arguments = $path =~ $regexp;
    my $leftover_path = eval q{$'};

    undef @arguments unless defined $1; # Just got the success indicator

    return {
        leftover_path => $leftover_path,
        match_arguments => \@arguments,
    };
}

package Path::TreeDispatcher::Branch;

use Any::Moose;

has rule => qw/ is ro /;
has sequence => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

sub add {
    my $self = shift;

    push @{ $self->sequence }, @_;

    return $self;
}

sub dispatch {
    my $self = shift;
    my $ctx = shift;

    my $path = $ctx->path;

    my $match;
    if ( my $rule = $self->rule ) {
        return unless $match = $rule->match( $path );
    }
    else {
        $match = { leftover_path => $path };
    }
    $match = $ctx->dispatcher->build_match( %$match, target_path => $path );

    $ctx->push( match => $match );

    for my $node (@{ $self->sequence }) {
        if ( blessed $node && $node->can( 'dispatch' ) ) {
            $node->dispatch( $ctx );
        }
        else {
            $ctx->visit( $node );
        }
    }

    $ctx->pop();
}

package Path::TreeDispatcher::Builder;

use Any::Moose;
use Path::TreeDispatcher::Carp;

has $_ => ( accessor => "_$_" )
    for qw/ parse_rule parse_branch /;

has build_branch =>
    qw/ accessor _build_branch default Path::TreeDispatcher::Branch /;

# $builder->parse_rule( ... )
# $parse->( $builder, ... )
sub parse_rule {
    my $builder = shift;
    my $input = shift;

    my $rule;

    $rule = $builder->_parse( $builder->_parse_rule, $input );
    return $rule if defined $rule; # TODO Check if $rule does Rule

    $rule = $builder->builtin_parse_rule( $input );
    return $rule if defined $rule;

    return undef;
}

sub builtin_parse_rule {
    my $builder = shift;
    my $input = shift;

    if ( ! defined $input ) { # undefined is an "Always match" rule
        return undef;
    }
    elsif ( ref $input eq 'Regexp' ) {
        return Path::TreeDispatcher::Rule::Regexp->new( regexp => $input );
    }

    croak "Do not know how to parse rule input ($input)";
}

# $builder->parse_branch( ... )
# $parse->( $builder, ... )
sub parse_branch {
    my $builder = shift;
    my @input = @_;

    my $branch;

    $branch = $builder->_parse( $builder->_parse_branch, @input );
    return $branch if defined $branch; # TODO? Check if $branch does branching role

    $branch = $builder->builtin_parse_branch( @input );
    return $branch if defined $branch;

    croak "Unable to parse branch from input";
}

sub builtin_parse_branch {
    my $builder = shift;
    my $rule = shift;
    my @add = @_;

    my $branch = $builder->build_branch( rule => $builder->parse_rule( $rule ) );
    $branch->add( @add ) if @add;
    return $branch;
}

# TODO? Die if unable to build
sub build_branch {
    my $self = shift;
    return $self->_build( $self->_build_branch, @_ );
}

sub _parse {
    my $self = shift;
    my $parse = shift;

    return unless $parse;

    if ( ref $parse eq 'CODE' ) {
        return $parse->( $self, @_ );
    }
    else {
        croak "Do not know how to parse with ($parse)";
    }
}

sub _build {
    my $self = shift;
    my $build = shift;

    if ( ref $build eq 'CODE' ) {
        return $build->( @_ );
    }
    elsif ( $build && ref $build eq '' ) {
        $build->new( @_ );
    }
    else {
        croak "Do not know how to build with ($build)";
    }
}

1;
