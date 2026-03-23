#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>

/* LED GPIO configuration */
#define LED_GPIO_PORT		"GPIO_0"
#define LED_GPIO_PIN		13
#define LED_BLINK_INTERVAL	K_MSEC(1000)

int main(void)
{
	const struct device *led_dev;
	int ret;

	printk("ESP32 LED Blink starting...\n");

	/* Get GPIO device */
	led_dev = device_get_binding(LED_GPIO_PORT);
	if (led_dev == NULL) {
		printk("ERROR: GPIO device not found\n");
		return 1;
	}

	/* Configure LED pin as output */
	ret = gpio_pin_configure(led_dev, LED_GPIO_PIN, GPIO_OUTPUT_ACTIVE);
	if (ret != 0) {
		printk("ERROR: Failed to configure LED pin\n");
		return 1;
	}

	printk("LED configured on pin %d. Starting blink...\n", LED_GPIO_PIN);

	/* Blink loop */
	while (1) {
		/* LED on */
		gpio_pin_set(led_dev, LED_GPIO_PIN, 1);
		printk("LED ON\n");
		k_sleep(LED_BLINK_INTERVAL);

		/* LED off */
		gpio_pin_set(led_dev, LED_GPIO_PIN, 0);
		printk("LED OFF\n");
		k_sleep(LED_BLINK_INTERVAL);
	}

	return 0;
}
