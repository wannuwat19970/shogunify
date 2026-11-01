import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shogunify/controllers/provider.dart';
import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/image_utils.dart';

void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color.fromARGB(255, 34, 34, 34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer2<PlayerController, States>(
        builder: (context, player, states, child) {
          final currentSong =
              (player.songQueue.isNotEmpty &&
                  player.currentIndex < player.songQueue.length &&
                  player.currentIndex >= 0)
              ? player.songQueue[player.currentIndex]
              : null;

          final upcoming = player.currentIndex >= 0
              ? player.songQueue.sublist(player.currentIndex + 1)
              : player.songQueue;

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Queue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (currentSong != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(text: 'Playing '),
                            TextSpan(
                              text: currentSong['title'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (currentSong != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const SizedBox(width: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 55,
                            height: 55,
                            child:
                                ImageUtils.resolveUrl(
                                      currentSong['album_art_url'],
                                    ) !=
                                    null
                                ? Image.network(
                                    ImageUtils.resolveUrl(
                                      currentSong['album_art_url'],
                                    )!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        ImageUtils.placeholder(),
                                  )
                                : ImageUtils.placeholder(),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong['title'] ?? 'Unknown Title',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 147, 132, 209),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentSong['artist'] != null
                                    ? '- ${currentSong['artist']}'
                                    : '- ArtistUnknown',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          onPressed: () {
                            if (player.isPlaying) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        if (states.isShuffling)
                          const Icon(
                            Icons.shuffle_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                        if (states.isShuffling) const SizedBox(width: 6),
                        Text(
                          states.isShuffling
                              ? 'Shuffling from:'
                              : 'Next in queue:',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: upcoming.isEmpty
                      ? const Center(
                          child: Text(
                            'Nothing queued next',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: upcoming.length,
                          itemBuilder: (context, index) {
                            final song = upcoming[index];
                            final realIndex = player.currentIndex + 1 + index;

                            return GestureDetector(
                              onTap: () => player.playFromQueue(realIndex),
                              child: Container(
                                height: 70,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 3),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 45,
                                        height: 45,
                                        child:
                                            ImageUtils.resolveUrl(
                                                  song['album_art_url'],
                                                ) !=
                                                null
                                            ? Image.network(
                                                ImageUtils.resolveUrl(
                                                  song['album_art_url'],
                                                )!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    ImageUtils.placeholder(),
                                              )
                                            : ImageUtils.placeholder(),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song['title'] ?? 'Unknown Title',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            song['artist'] != null
                                                ? '- ${song['artist']}'
                                                : '- ArtistUnknown',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.drag_handle_rounded,
                                      color: Colors.white24,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => states.toggleShuffle(),
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 45, 45, 45),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shuffle_rounded,
                                  color: states.isShuffling
                                      ? const Color.fromARGB(255, 147, 132, 209)
                                      : Colors.white,
                                  size: 26,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Shuffle',
                                  style: TextStyle(
                                    color: states.isShuffling
                                        ? const Color.fromARGB(
                                            255,
                                            147,
                                            132,
                                            209,
                                          )
                                        : Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 45, 45, 45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Timer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
