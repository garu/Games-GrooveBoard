package Games::GrooveBoard;
use strict;
use warnings;

use SDL;
use SDLx::App;
use Class::Unload;
use SDL::Video;

sub start {
    my $app = SDLx::App->new(
        title  => 'Groove Board',
        width  => 800,
        height => 600,
        eoq    => 1,
        flags  => SDL_ANYFORMAT|SDL_DOUBLEBUF,
    );

    # initial state
    my $state = 'Level';

    while ($state) {
        my $class = 'Games::GrooveBoard::' . $state;
        eval "require $class";
        die "error loading $class: $@" if $@;
        $class->startup( $app );

        $app->run;
        $app->remove_all_handlers;

        Class::Unload->unload($class);
        $state = $app->stash->{next_state};
        $app->stash->{next_state} = undef;
    }
}



'one two step!';
