package Games::GrooveBoard::Level;
use strict;
use warnings;
use SDL;
use SDL::Event;
use SDL::Events;
use SDL::Rect;
use SDLx::Surface;
use SDLx::Controller::Interface;
use SDLx::Text;
use SDL::Mixer;
use SDL::Mixer::Music;
use Time::HiRes qw(gettimeofday tv_interval);
use constant {
    UP    => 1,
    DOWN  => 2,
    LEFT  => 4,
    RIGHT => 8,
};


sub startup {
    my ($self, $app) = @_;

    die "error opening audio"
        unless SDL::Mixer::open_audio( 44100, AUDIO_S16SYS, 2, 4096 ) == 0;

    my $score_text  = SDLx::Text->new( h_align => 'right', size => 36 );
    my $score  = 0;

    my $message = SDLx::Text->new( x => 450, y => 45, size => 42, text => ' ' );
    my $combo_text = SDLx::Text->new( y => 520, size => 48, h_align => 'right' );
    my $combo = 0;

    my $arrows = SDLx::Surface->load('data/arrows.png');
    my $down   = SDL::Rect->new(0,0,90,90);
    my $left   = SDL::Rect->new(91,0,90,90);
    my $right  = SDL::Rect->new(181,0,90,90);
    my $up     = SDL::Rect->new(271,0,90,90);

    my ($BPS, %song) = load_song('data/song1.step');

    my $background = SDLx::Surface->load('data/background.png');
    $background->blit($app);

    my $last_show_id;
    my $last_show = sub {
        my ($delta, $app) = @_;
        $arrows->blit($app, $left,  [ 10, 10, 0, 0] );
        $arrows->blit($app, $up,    [100, 10, 0, 0] );
        $arrows->blit($app, $down,  [200, 10, 0, 0] );
        $arrows->blit($app, $right, [300, 10, 0, 0] );

        $app->flip;
    };

    my $t0;
    my $music;
    my $beat = 0;
    my %on_screen = ();

    # paint our moving arrows
    my $update_interface = sub {
        my ($state, $id) = @_;
        my $item = $on_screen{$id};
        my $rect = $item->{arrow};

#        if (my $previous = $item->{previous}) {
#            $background->blit( $app, $rect, [$previous->x, $previous->y, 0, 0] );
#        }

        if ($state->y + $rect->h > 0) {
            $arrows->blit( $app, $rect, [$state->x, $state->y, 0, 0] );
            $item->{previous} = $state;
        }
        else {
            $item->{interface}->detach();
            delete $on_screen{$id};
            $message->color( [255,0,0,100] );
            $message->text('MISS :(');
            $message->y(45);
            $combo = 0;
        }
        return;
    };


    # paint over the guide arrows and draw the score
    $app->add_show_handler( sub {
#        $background->blit($app, [0,0,$app->w,100], [0,0,0,0] );
        $background->blit($app); #TODO DELETE AFTER FIXING
        $score_text->write_to($app, $score);

        my $y = $message->y;
        if ($y > 100) {
            $message->text( ' ' );
        }
        else {
            $message->y( $y + 1 )
        }
        $message->write_to($app);

        if ($combo >= 10) {
            $combo_text->write_to($app, $combo . ' Hit Combo! ');
        }
    });

    $app->add_show_handler( sub {

        if (not defined $t0) {
            $music = SDL::Mixer::Music::load_MUS( 'data/music.ogg' );
            SDL::Mixer::Music::play_music($music, 0);
            $t0 = [gettimeofday()];
        }
        else {
            my $new_beat = int ( tv_interval($t0, [gettimeofday]) * $BPS );
            if ($new_beat > $beat) {
                $beat = $new_beat;
                if ( exists $song{$beat} ) {
                    my $new_arrows = $song{$beat};

                    my @items = ();
                    if ($new_arrows & UP) {
                        push @items, { x => 100, arrow_x => 271, label => $beat . 'up' };
                    }
                    if ($new_arrows & DOWN) {
                        push @items, { x => 200, arrow_x => 0, label => $beat . 'down' };
                    }
                    if ($new_arrows & LEFT) {
                        push @items, { x => 10, arrow_x => 91, label => $beat . 'left' };
                    }
                    if ($new_arrows & RIGHT) {
                        push @items, { x => 300, arrow_x => 181, label => $beat . 'right' };
                    }

                    foreach my $item (@items) {
                        my $interface = SDLx::Controller::Interface->new( x => $item->{x}, y => $app->h, v_y => -60 );
                        $interface->set_acceleration( sub { return (0,0,0) } );
                        $interface->attach( $app, $update_interface, $item->{label});
                        
                        $on_screen{ $item->{label} } = {
                            arrow => SDL::Rect->new($item->{arrow_x},180,90,90),
                            interface => $interface,
                        };
                    }

                    # we need to make sure our guide arrows
                    # are the very last thing blitted on screen
                    # so we make this horrible, horrible hack
                    # (did I mention it's a 1-week game contest?)
                    $app->remove_show_handler($last_show_id);
                    $last_show_id = $app->add_show_handler( $last_show );
                }
            }
        }
            
    });


    # finally, paint our own arrows
    $last_show_id = $app->add_show_handler( $last_show ); 


    # handlig our events
    $app->add_event_handler( sub {
        my ($event, $app) = @_;

        my $value;
        my $pressed;
        if ($event->type == SDL_KEYDOWN) {
            $value = 90;
            # 'up', 'down', 'left', 'right', like what we have in your on_screen labels
            $pressed = SDL::Events::get_key_name($event->key_sym);
        }
        elsif ($event->type == SDL_KEYUP) {
            $value = 0;
        }

        if (defined $value) {
            my $key = $event->key_sym;
            if ($key == SDLK_UP) {
                $up->y($value);
                                }
            elsif ($key == SDLK_DOWN) {
                $down->y($value);
            }
            elsif ($key == SDLK_LEFT) {
                $left->y($value);
            }
            elsif ($key == SDLK_RIGHT) {
                $right->y($value);
            }

            if ($pressed) {
               my @total = grep {
                  rindex($_, $pressed) != -1
                  and $on_screen{$_}->{interface}
                                    ->current->y < 100
               } keys %on_screen;

               if (@total) {
                   # '10' is the offset where we start
                   # drawing our source arrows
                   my $proximity = abs( 10 - $on_screen{$total[0]}->{interface}->current->y);
                   $score += 1000 - ($proximity * 10);

                   my $msg_text = ' ';
                   if ($proximity > 30) {
                      $msg_text = 'BAD';
                      $message->color( [255,0,0,100] );
                      $combo = 0;
                   }
                   elsif ($proximity > 20) {
                       $msg_text = 'OK';
                       $message->color( [255,255,0,100] );
                   }
                   elsif ($proximity > 10) {
                       $msg_text = 'GOOD';
                       $message->color( [0,255,0,100] );
                   }
                   elsif ($proximity <= 10) {
                       $msg_text = 'PERFECT!!';
                       $message->color( [0,0,255,100] );
                   }
                   $message->text( $msg_text );
                   $message->y(45);

                   foreach my $id (@total) {
                       $on_screen{$id}->{interface}->detach();
                       delete $on_screen{$id};
                       $combo++;
                   }
               }
            }
        }
    });
}

sub load_song {
    my $filename = shift;

    open my $fh, '<', $filename
        or die "Error loading '$filename': $!";

    my ($BPS, %keys);
    while (my $line = <$fh>) {
        next if $line =~ /^(?:#.+)?\s*$/;
        if ($line =~ /^BPS\s*:\s*(\d)/) {
            $BPS = $1;
        }
        elsif ($line =~ /^(\d+)\s*:\s*([LRUD]+)\s*$/) {
            my ($index, $keys_to_insert) = ($1, $2);
            my $mask = 0;
            $mask |= LEFT  unless index($keys_to_insert, 'L') == -1;
            $mask |= RIGHT unless index($keys_to_insert, 'R') == -1;
            $mask |= UP    unless index($keys_to_insert, 'U') == -1;
            $mask |= DOWN  unless index($keys_to_insert, 'D') == -1;

            $keys{$index} = $mask;
        }
    }
    return ($BPS, %keys);
}


"Hey! Ho! Let's go!"
