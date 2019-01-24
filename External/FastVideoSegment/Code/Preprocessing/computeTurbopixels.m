% Wrapper to compute the TurboPixels oversegmentation method for a given shot
%
%    Copyright (C) 2013  Anestis Papazoglou
%
%    You can redistribute and/or modify this software for non-commercial use
%    under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%    For commercial use, contact the author for licensing options.
%
%    Contact: a.papazoglou@sms.ed.ac.uk

function turbopixels = computeTurbopixels( options, shot )

    startFrame = options.ranges( shot );
    frames = options.ranges( shot + 1 ) - options.ranges( shot );

    totalTimeTaken = 0;
    
    turbopixels = cell( frames, 1 );
    for( index = 1: frames )

        tic;
        if( options.vocal )
            fprintf( 'computeTurbopixels: Processing frame %i/%i... ', ...
            index, frames );
        end

        frameid = startFrame + index - 1;
        frame = im2double( readFrame( options, frameid ) );

        [ ~, boundary, ~ ] = superpixels( frame, 1500 );
        turbopixels{ index } = fillTurboPixels( uint16( ...
            bwlabel( ~boundary, 4 ) ) );
        
        timeTaken = toc;
        totalTimeTaken = totalTimeTaken + timeTaken;
        
        if( options.vocal )
            fprintf( 'time taken: %.2f seconds\n', timeTaken );
        end
    end
    
    if( options.vocal )
        fprintf( 'computeTurbopixels: Total time taken: %.2f sec\n', totalTimeTaken );
        fprintf( 'computeTurbopixels: Average time taken per frame: %.2f sec\n', ...
            totalTimeTaken / frames );
    end
    
end
