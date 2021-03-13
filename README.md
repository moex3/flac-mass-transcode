# flac-mass-transcode
It will find every flac file and transcode them to opus files, while keeping the directory structure, adding album covers where possible. If another type of music file is found, like mp3's, it will be copied over without transcoding.

# Usage
```bash
./flac-mass-transcode ~/music_input_dir ~/music_output_dir
```

## The --uplevel flag
Let's say you only want to copy over 1 album, while keeping the directory. -u 1 can be used for that. For example.
```bash
./flac-mass-transcode ~/music/album ~/output
```
This would put every file in album under output.

```bash
./flac-mass-transcode -u 1 ~/music/album ~/output
```
This will create an album directory under output, and put the files there.
