package Path::Tree::Rule;

package Path::Tree::Rule::Regexp;

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

package Path::Tree::Rule::TokenRegexp;

use Any::Moose;

has tokenlist => qw/ is ro required 1 isa ArrayRef /;
has delimeter => qw/ is ro required 1 isa Str /, default => ' ';
has regexp => qw/ is ro lazy_build 1 /;
sub _build_regexp {
    my $self = shift;
    my $tokenlist = $self->tokenlist;
    my $delimeter = $self->delimeter;
    my @tokenlist = grep { length } map { split $delimeter } @$tokenlist;
    my $regexp = join "(?:$delimeter)*", '', @tokenlist, '';
    return qr/^$regexp/;
}

sub match {
    my $self = shift;
    my $path = shift;

    return Path::Tree::Rule::Regexp->regexp_match( $path, $self->regexp );
}

package Path::Tree::Rule::SlashPattern;

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

    return Path::Tree::Rule::Regexp->regexp_match( $path, $self->regexp );
}

package Path::Tree::Rule::Always;

use Any::Moose;

sub match {
    my $self = shift;
    my $path = shift;

    return {
        leftover => $path,
    };
}

1;
