#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
	printk("Hello from native_project (Zephyr v3.7.0, native_posix_64)\\n");
	return 0;
}
