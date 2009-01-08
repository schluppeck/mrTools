% linkFile.m
%
%        $Id$ 
%      usage: linkFile(fromFilename,toFilename)
%         by: justin gardner
%       date: 01/08/09
%    purpose: links fromFilename to toFilename. Will make the link into a
%             relative filename if possible.
%
function retval = linkFile(fromFilename,toFilename)

% check arguments
if ~any(nargin == [2])
  help linkFile
  return
end

% The command to use to link
linkcommand = 'ln -s';

% check to make sure fromFilename exists
if ~isfile(fromFilename)
  disp(sprintf('(linkFile) %s does not exist',fromFilename));
  return
end

if isempty(toFilename)
  disp(sprintf('(linkFile) Must specify a toFilename'));
  return
end

% make fromFilename fully qualified
if ~strcmp(fromFilename(1),filesep) && ~strcmp(fromFilename(1),'.')
  fromFilename = fullfile(pwd,fromFilename);
end

% changed to the directory of the toFilename and get its path
initPath = pwd;
[toPath toName toExt] = fileparts(toFilename);
toName = [toName toExt];
if ~isempty(toPath)
  cd(toPath);
end
toPath = pwd;

% break up the fromFilename
[fromPath fromName fromExt] = fileparts(fromFilename);
fromName = [fromName fromExt];

% now make toFilename relative
fromRelativeFilename = '';
if strcmp(fromFilename(1),filesep)
  % look for where the paths are different from each other
  [fromTop fromRest] = strtok(fromPath,filesep);
  [toTop toRest] = strtok(toPath,filesep);
  while strcmp(fromTop,toTop)
    [fromTop fromRest] = strtok(fromRest,filesep);
    [toTop toRest] = strtok(toRest,filesep);
  end
  % if they are both empty, then good they are in the same directory
  if isempty(fromTop) && isempty(toTop)
    fromRelativeFilename = fromName;
  else 
    % now make the string that will take us up to the common directory
    upDir = '';
    while ~isempty(toTop)
      upDir = fullfile('..',upDir);
      [toTop toRest] = strtok(toRest,filesep);
    end
    % and make the string that will take us down to the from directory
    if ~isempty(fromTop) && ~isempty(fromRest)
      downDir = fullfile(fromTop,fromRest);
    elseif ~isempty(fromTop)
      downDir = fromTop;
    else
      downDir = '';
    end
    % now make the from file as a relative path
    fromRelativeFilename = fullfile(upDir,downDir,fromName);
  end
end

% make the link command
if ~isempty(fromRelativeFilename)      
  linkcommand = sprintf('%s %s %s',linkcommand,fromRelativeFilename,toName);
else
  linkcommand = sprintf('%s %s %s',linkcommand,fromFilename,toName);
end
disp(sprintf('(linkFile) %s',linkcommand));
system(linkcommand);

% cd back to initial path
cd(initPath);

