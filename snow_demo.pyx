import os
import pygame
from pygame import DOUBLEBUF, KEYDOWN, K_ESCAPE, QUIT, NOFRAME, FULLSCREEN
from random import randint
import numpy as np
from cpython cimport bool


cdef int WIDTH = 1600
cdef int HEIGHT = 1000
cdef int FPS = 40
cdef int FONT_H = HEIGHT // 7
cdef int NUM_FLAKES = 5000#WIDTH * HEIGHT // 200
cdef int MIN_SPEED = 1
cdef int MAX_SPEED = 3

flake_img_py = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
cdef unsigned char [:, :, :] flake_img = flake_img_py

static_img_py = np.zeros((HEIGHT * 2, WIDTH, 3), np.uint8)
cdef unsigned char [:, :, :] static_img = static_img_py

cdef struct flake_t:
    int x
    double y
    double v

flake_array = []
# cdef flake_t* flake_array

def init_flakes():
    for _ in range(NUM_FLAKES):
        speed = randint(MIN_SPEED * 10, MAX_SPEED * 10) / 10 if MIN_SPEED < MAX_SPEED else MIN_SPEED
        flake_array.append([randint(0, WIDTH - 1), randint(0, HEIGHT), speed])


cdef int grab_grid(int x, int y):
    cdef int x_min, x_max, y_min, local_slope
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
            local_slope = 2
        else:
            local_slope = 0
    return local_slope


cdef bool can_flake_settle(flake):
    cdef int offset, flake_x, flake_y, check_y, action, chance
    flake_x = flake[0]
    for offset in range(MIN_SPEED, MAX_SPEED + 1):
        flake_y = int(flake[1])
        check_y = flake_y + offset
        chance = randint(1, 102) % 51
        if check_y == HEIGHT * 2:
            set_pixel(static_img[check_y - 1, flake_x], [255, 255, 255])
            set_pixel(flake_img[flake_y, flake_x], [0, 0, 0])
            flake[0] = randint(0, WIDTH - 1)
            flake[1] = HEIGHT
            return True
        elif is_pixel_full(static_img[check_y, flake_x]):
            action = grab_grid(flake_x, check_y)
            set_pixel(flake_img[flake_y, flake_x], [0, 0, 0])
            if action == -1:
                if chance != 0:
                    flake[0] = flake[0] + 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
            elif action == 1:
                if chance != 0:
                    flake[0] = flake[0] - 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
            elif action == 2:
                if chance < 25:
                    flake[0] = flake[0] - 1
                    return False
                elif chance > 25:
                    flake[0] = flake[0] + 1
                    return False
                else:
                    return settle_flake(flake, check_y - 1)
            else:
                return settle_flake(flake, check_y - 1)
    return False


cdef bool settle_flake(flake, int y):
    cdef int flake_x = flake[0]
    set_pixel(static_img[y, flake_x], [255, 255, 255])
    flake[0] = randint(0, WIDTH - 1)
    flake[1] = HEIGHT
    return True


cdef bool is_pixel_empty(unsigned char[:] pixel):
    cdef int i
    cdef bool result = True
    for i in range(3):
        result &= pixel[i] == 0
    return result


cdef bool is_pixel_full(unsigned char[:] pixel):
    cdef int i
    cdef bool result = False
    for i in range(3):
        result |= pixel[i] != 0
    return result


cdef void set_pixel(unsigned char[:] pixel, unsigned char* value):
    cdef int i
    for i in range(3):
        pixel[i] = value[i]


cdef void update_flakes():
    cdef int old_x, new_x, old_y, new_y
    for flake in flake_array:
        old_x = flake[0]
        if not can_flake_settle(flake):
            old_y = int(flake[1])
            set_pixel(flake_img[old_y, old_x], [0, 0, 0])
            flake[1] += flake[2]
            new_x = flake[0]
            new_y = int(flake[1])
            if flake[1] >= 2 * HEIGHT:
                flake[1] = 2 * HEIGHT - MIN_SPEED
            elif is_pixel_full(static_img[new_y, new_x]):
                flake[1] -= flake[2]
        new_x = flake[0]
        new_y = int(flake[1])
        r = randint(1, 100)
        if r < 21:
            if new_x > 0 and is_pixel_empty(static_img[new_y, new_x - 1]):
                flake[0] -= 1
        elif r > 80:
            if new_x < WIDTH - 1 and is_pixel_empty(static_img[new_y, new_x + 1]):
                flake[0] += 1
        new_x = flake[0]
        set_pixel(flake_img[new_y, new_x], [255, 255, 255])


def draw_flakes(screen):
    update_flakes()
    img = pygame.image.frombuffer(flake_img_py.tostring(), (WIDTH, 2 * HEIGHT), "RGB")
    img.set_colorkey((0, 0, 0))
    img2 = pygame.image.frombuffer(static_img_py.tostring(), (WIDTH, 2 * HEIGHT), "RGB")
    img2.blit(img, (0, 0))
    screen.blit(img2, (0, -HEIGHT))


def draw_text(screen, text):
    x, y = screen.get_size()
    x_pix = 0
    y_pix = 0
    num_text = 0
    incr = 0
    num_text = len(text)
    max_width = max(text, key=len)
    while x_pix < WIDTH * 0.9 and y_pix < HEIGHT * 0.9:
        font = pygame.font.SysFont('arial', FONT_H + incr, bold=True)
        x_pix, y_pix = font.size(max_width)
        incr += 1
    rect = pygame.Rect((x - x_pix) // 2, (y - (y_pix * num_text)) // 2, x_pix, y_pix * num_text)

    for i, t in enumerate(text):
        fw, fh = font.size(t)
        surface = font.render(t, True, (255, 0, 0))
        screen.blit(surface, ((x - fw) // 2, (i * fh) + (y - (fh * num_text)) // 2))

    return rect

def int_to_rgb(number):
    if number == 0:
        return 0, 0, 0
    blue = number & 255
    green = (number >> 8) & 255
    red = (number >> 16) & 255
    return red, green, blue


def copy_text_to_image(background):
    cdef int col, row
    background.fill((0, 0, 0))
    rect = draw_text(background, [" ** MERRY ** ", "CHRISTMAS"])
    # rect = draw_text(background, ["HAPPY", "HOLIDAYS"])
    text_pixels = pygame.PixelArray(background).transpose()
    for col in range(rect.top, rect.bottom + 1):
        for row in range(rect.left, rect.right + 1):
            r, g, b = int_to_rgb(text_pixels[col][row])
            set_pixel(static_img[col + HEIGHT, row], [r, g, b])
    del text_pixels


def restart(background, screen):
    cdef bool running = True
    global flake_img_py
    global static_img_py
    copy_text_to_image(background)
    init_flakes()
    clock = pygame.time.Clock()
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
        _, counts = np.unique(static_img_py[HEIGHT, :], return_counts=True)
        if len(counts) > 1 and counts[1] // 3 > WIDTH * 0.9:
            flake_img_py.fill(0)
            static_img_py.fill(0)
            flake_array.clear()
            copy_text_to_image(background)
            init_flakes()

        pygame.display.flip()
        screen.blit(background, (0, 0))


def run():
    os.environ['SDL_VIDEO_CENTERED'] = '1'
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT), DOUBLEBUF | NOFRAME)# | FULLSCREEN)
    background = pygame.Surface(screen.get_size()).convert()

    restart(background, screen)

    pygame.quit()
