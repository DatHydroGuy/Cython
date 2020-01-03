import os
import pygame
from pygame import DOUBLEBUF, KEYDOWN, K_ESCAPE, QUIT, NOFRAME
from random import randint
import numpy as np


WIDTH = 800
HEIGHT = 600
FPS = 60
FONT_H = HEIGHT // 7
NUM_FLAKES = WIDTH * HEIGHT // 200
flake_array = []
flake_img = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
static_img = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
BLACK = np.array([0, 0, 0], np.uint8)
WHITE = np.array([255, 255, 255], np.uint8)
MIN_SPEED = 1
MAX_SPEED = 3


def init_flakes():
    for _ in range(NUM_FLAKES):
        speed = randint(MIN_SPEED * 10, MAX_SPEED * 10) / 10 if MIN_SPEED < MAX_SPEED else MIN_SPEED
        flake_array.append([randint(0, WIDTH - 1), randint(0, HEIGHT), speed])


def is_pixel_empty(pixel):
    return (pixel == BLACK).all()


def is_pixel_full(pixel):
    return (pixel != BLACK).any()


def grab_grid(x, y):
    x_min = max(0, x - 1)
    x_max = min(WIDTH - 1, x + 1)
    y_min = max(0, y - 1)
    if x_min == WIDTH - 2:
        if is_pixel_empty(static_img[y, x_min]):
            local_slope = 1
        else:
            local_slope = 0
    elif x_max == 1:
        if is_pixel_empty(static_img[y, x_max]):
            local_slope = -1
        else:
            local_slope = 0
    else:
        if is_pixel_full(static_img[y_min, x_min]):
            if is_pixel_empty(static_img[y, x_max]):
                local_slope = -1
            else:
                local_slope = 0
        elif is_pixel_full(static_img[y_min, x_max]):
            if is_pixel_empty(static_img[y, x_min]):
                local_slope = 1
            else:
                local_slope = 0
        elif is_pixel_empty(static_img[y, x_min]) and is_pixel_empty(static_img[y, x_max]):
            local_slope = 0.5
        else:
            local_slope = 0
    return local_slope


def can_flake_settle(flake):
    flake_x = flake[0]
    for offset in range(MIN_SPEED, MAX_SPEED + 1):
        flake_y = int(flake[1])
        check_y = flake_y + offset
        if check_y == HEIGHT * 2:
            static_img[check_y - 1, flake_x] = WHITE
            flake_img[flake_y, flake_x] = BLACK
            flake[0] = randint(0, WIDTH - 1)
            flake[1] = HEIGHT
            return True
        elif is_pixel_full(static_img[check_y, flake_x]):
            action = grab_grid(flake_x, check_y)
            flake_img[flake_y, flake_x] = BLACK
            if action == -1:
                if randint(1, 100) % 10 != 0:
                    flake[0] = flake[0] + 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
                    # return True
            elif action == 1:
                if randint(1, 100) % 10 != 0:
                    flake[0] = flake[0] - 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
                    # return True
            elif action == 0.5:
                temp = randint(1, 105) % 21
                if temp < 10:
                    flake[0] = flake[0] - 1
                    return False
                elif temp > 10:
                    flake[0] = flake[0] + 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
                    # return True
            else:
                return settle_flake(flake, check_y - 1)
                # static_img[check_y - 1, flake[0]] = WHITE
                # flake[0] = randint(0, WIDTH - 1)
                # flake[1] = HEIGHT
                # return True
    return False


def settle_flake(flake, y):
    static_img[y, flake[0]] = WHITE
    flake[0] = randint(0, WIDTH - 1)
    flake[1] = HEIGHT
    return True


def update_flakes():
    for flake in flake_array:
        if not can_flake_settle(flake):
            flake_img[int(flake[1]), flake[0]] = BLACK
            flake[1] += flake[2]
            if flake[1] >= 2 * HEIGHT:
                flake[1] = 2 * HEIGHT - MIN_SPEED
            elif is_pixel_full(static_img[int(flake[1]), flake[0]]):
                flake[1] -= flake[2]
        flake_img[int(flake[1]), flake[0]] = WHITE


def draw_flakes(screen):
    update_flakes()
    img = pygame.image.frombuffer(flake_img.tostring(), (WIDTH, 2 * HEIGHT), "RGB")
    img.set_colorkey(BLACK)
    img2 = pygame.image.frombuffer(static_img.tostring(), (WIDTH, 2 * HEIGHT), "RGB")
    img2.blit(img, (0, 0))
    screen.blit(img2, (0, -HEIGHT))


def draw_text(screen, text):
    x, y = screen.get_size()
    font = pygame.font.SysFont('arial', FONT_H, bold=True)
    num_text = len(text)
    max_width = max(text, key=len)
    x_pix, y_pix = font.size(max_width)
    rect = pygame.Rect((x - x_pix) // 2, (y - (y_pix * num_text)) // 2, x_pix, y_pix * num_text)

    for i, t in enumerate(text):
        fw, fh = font.size(t)
        surface = font.render(t, True, (255, 0, 0))
        screen.blit(surface, ((x - fw) // 2, (i * fh) + (y - (fh * num_text)) // 2))

    return rect


def int_to_rgb(number):
    if number == 0:
        return [0, 0, 0]
    blue = number & 255
    green = (number >> 8) & 255
    red = (number >> 16) & 255
    return [red, green, blue]


def copy_text_to_image(background):
    background.fill((0, 0, 0))
    rect = draw_text(background, [" ** MERRY ** ", "CHRISTMAS"])
    text_pixels = pygame.PixelArray(background).transpose()
    for col in range(rect.top, rect.bottom + 1):
        for row in range(rect.left, rect.right + 1):
            static_img[col + HEIGHT, row] = int_to_rgb(text_pixels[col][row])
    del text_pixels


def restart(background, screen):
    global flake_img
    global static_img
    copy_text_to_image(background)
    init_flakes()
    clock = pygame.time.Clock()
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == QUIT:
                running = False
            elif event.type == KEYDOWN:
                if event.key == K_ESCAPE:
                    running = False

        clock.tick(FPS)
        background.fill((0, 0, 0))
        draw_flakes(background)
        _, counts = np.unique(static_img[HEIGHT, :], return_counts=True)
        if len(counts) > 1 and counts[1] // 3 > WIDTH * 0.75:
            flake_img = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
            static_img = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
            copy_text_to_image(background)
            flake_array.clear()
            init_flakes()

        pygame.display.flip()
        screen.blit(background, (0, 0))


def run():
    os.environ['SDL_VIDEO_CENTERED'] = '1'
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT), DOUBLEBUF | NOFRAME)
    background = pygame.Surface(screen.get_size()).convert()

    restart(background, screen)

    pygame.quit()


if __name__ == '__main__':
    run()
