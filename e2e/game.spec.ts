import { test, expect, type Page } from '@playwright/test';
const choose = async (page: Page, label: string) =>
  page.getByRole('button', { name: label, exact: false }).click();
const assign = async (page: Page, worker: string, task: string) =>
  page.getByLabel(`${worker}'s task`).selectOption(task);
async function finishWork(page: Page, choice: string) {
  await choose(page, 'Review the season');
  await choose(page, 'Confirm and resolve');
  await choose(page, choice);
  await choose(page, 'Continue to');
}
test('new household, promise, work preview and save resume', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('/');
  await expect(page.locator('#scene')).toHaveAttribute('data-ready', 'true');
  await expect(
    page.getByRole('heading', { name: 'A favour in the furrows' }),
  ).toBeVisible();
  await choose(page, 'Accept his kindness');
  await expect(
    page.getByText('One adult owed to the neighbour in autumn.', {
      exact: true,
    }),
  ).toBeVisible();
  await assign(page, 'Ion', 'plant');
  await assign(page, 'Ana', 'repair');
  await assign(page, 'Petru', 'paid');
  await choose(page, 'Review the season');
  await expect(page.getByRole('dialog')).toContainText('Seed');
  await choose(page, 'Keep planning');
  await page.reload();
  await expect(page.getByLabel("Ion's task")).toHaveValue('plant');
  await finishWork(page, 'Keep our own table');
  await expect(
    page.getByRole('heading', { name: 'A place of his own' }),
  ).toBeVisible();
  expect(errors).toEqual([]);
});
for (const path of ['honour', 'break', 'pay', 'decline'])
  test(`complete year: ${path}`, async ({ page }) => {
    await page.goto('/');
    await choose(
      page,
      path === 'pay'
        ? 'Pay for the ox'
        : path === 'decline'
          ? 'Work with what we have'
          : 'Accept his kindness',
    );
    await assign(page, 'Ion', 'plant');
    await assign(page, 'Ana', 'repair');
    await assign(page, 'Petru', 'paid');
    await finishWork(page, 'Keep our own table');
    await choose(page, 'Promise him a fair share');
    await assign(page, 'Ion', 'tend');
    await assign(page, 'Ana', 'paid');
    await assign(page, 'Petru', 'repair');
    await finishWork(page, 'Let the crop ripen');
    await choose(
      page,
      path === 'honour'
        ? 'Send Petru to help him'
        : path === 'break'
          ? 'Keep everyone at home'
          : 'Gather the household',
    );
    if (path === 'honour')
      await expect(page.getByLabel("Petru's task")).toBeDisabled();
    await assign(page, 'Ion', 'harvest');
    await assign(page, 'Ana', 'harvest');
    if (path !== 'honour') await assign(page, 'Petru', 'paid');
    await finishWork(page, 'Settle the disagreement');
    await choose(
      page,
      path === 'break' ? 'Return home and make do' : 'Ask for a little help',
    );
    await assign(page, 'Ion', 'repair');
    await assign(page, 'Ana', 'supplies');
    await assign(page, 'Petru', 'paid');
    await finishWork(page, 'Sit together by the fire');
    await expect(
      page.getByText('The year you made', { exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: 'Begin another year' }),
    ).toBeVisible();
    await page.reload();
    await expect(
      page.getByText('The year you made', { exact: true }),
    ).toBeVisible();
    await choose(page, 'Begin another year');
    await expect(page.getByRole('dialog')).toContainText(
      'replace the year saved',
    );
    await choose(page, 'Keep this household');
    await expect(
      page.getByText('The year you made', { exact: true }),
    ).toBeVisible();
    await choose(page, 'Begin another year');
    await choose(page, 'Start a fresh household');
    await expect(
      page.getByRole('heading', { name: 'A favour in the furrows' }),
    ).toBeVisible();
    await page.reload();
    await expect(
      page.getByRole('heading', { name: 'A favour in the furrows' }),
    ).toBeVisible();
  });
test('invalid save offers an explicit fresh start', async ({ page }) => {
  await page.addInitScript(() =>
    localStorage.setItem('razes.household.v1', '{"version":99}'),
  );
  await page.goto('/');
  await expect(page.getByRole('alert')).toContainText('unsupported');
  await choose(page, 'Start a fresh household');
  await expect(
    page.getByRole('heading', { name: 'A favour in the furrows' }),
  ).toBeVisible();
});
test('keyboard actions and reduced motion remain usable', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(
    page.getByRole('button', { name: 'Reduce motion' }),
  ).toHaveAttribute('aria-pressed', 'true');
  await page.getByRole('button', { name: /Accept his kindness/ }).focus();
  await page.keyboard.press('Enter');
  await expect(page.getByLabel("Ion's task")).toBeVisible();
  await page.getByRole('button', { name: 'Open promise journal' }).click();
  await expect(page.getByRole('dialog')).toContainText('A promise to Vasile');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).not.toBeVisible();
});

test('all four seasonal scenes render, with planting, repaired shelter and different stores', async ({
  page,
}, testInfo) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('#scene')).toHaveAttribute('data-ready', 'true');
  const pictures: string[] = [];
  async function shot(name: string) {
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: testInfo.outputPath(`${name}.png`),
      fullPage: true,
    });
    const pixels = await page
      .locator('canvas')
      .evaluate((canvas: HTMLCanvasElement) => {
        const c = canvas.getContext('2d')!,
          data = c.getImageData(0, 0, canvas.width, canvas.height).data;
        const colors = new Set<string>();
        for (let i = 0; i < data.length; i += 4000)
          colors.add(`${data[i]},${data[i + 1]},${data[i + 2]}`);
        return { colors: colors.size, image: canvas.toDataURL() };
      });
    expect(pixels.colors).toBeGreaterThan(50);
    pictures.push(pixels.image);
  }
  await shot('spring-damaged');
  await choose(page, 'Accept his kindness');
  await assign(page, 'Ion', 'plant');
  await assign(page, 'Ana', 'repair');
  await assign(page, 'Petru', 'paid');
  await choose(page, 'Review the season');
  await choose(page, 'Confirm and resolve');
  await shot('spring-planted-repaired');
  await choose(page, 'Accept the grain with thanks');
  await choose(page, 'Continue to');
  await shot('summer');
  await choose(page, 'Promise him a fair share');
  await assign(page, 'Ion', 'tend');
  await assign(page, 'Ana', 'paid');
  await assign(page, 'Petru', 'repair');
  await finishWork(page, 'Let the crop ripen');
  await shot('autumn-ripe');
  await choose(page, 'Send Petru to help him');
  await assign(page, 'Ion', 'harvest');
  await assign(page, 'Ana', 'harvest');
  await choose(page, 'Review the season');
  await choose(page, 'Confirm and resolve');
  await shot('autumn-harvested-full-stores');
  await choose(page, 'Settle the disagreement');
  await choose(page, 'Continue to');
  await shot('winter');
  expect(new Set(pictures).size).toBe(6);
  await page.getByRole('button', { name: 'Open promise journal' }).click();
  await expect(page.getByRole('dialog')).toContainText('A promise kept');
});

test('laptop controls fit without horizontal overflow and dialog returns keyboard focus', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.goto('/');
  await expect(page.locator('#scene')).toHaveAttribute('data-ready', 'true');
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  const journal = page.getByRole('button', { name: 'Open promise journal' });
  await journal.focus();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(journal).toBeFocused();
  await choose(page, 'Accept his kindness');
  await choose(page, 'Sow the field');
  await page.getByRole('button', { name: /Ion Currently/ }).click();
  await expect(page.getByLabel("Ion's task")).toHaveValue('plant');
});

test('resources and current season stay visible while planning lower on the page', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.goto('/');
  await choose(page, 'Accept his kindness');
  await page.getByLabel("Ion's task").scrollIntoViewIfNeeded();
  const bounds = await page.locator('#resources').boundingBox();
  expect(bounds!.y).toBeGreaterThanOrEqual(0);
  await expect(page.locator('#topbar')).toContainText('Spring · Year one');
});

test('painted layers load and reduced motion freezes the canvas', async ({
  page,
}) => {
  const failures: string[] = [];
  page.on('pageerror', (error) => failures.push(error.message));
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('#scene')).toHaveAttribute('data-ready', 'true');
  await expect(page.locator('#scene')).toHaveAttribute('data-field', 'bare');
  await expect(page.locator('#scene')).toHaveAttribute(
    'data-visitor',
    'vasile',
  );
  await expect(page.locator('#scene')).not.toHaveAttribute('data-error');
  const snapshot = () =>
    page.locator('canvas').evaluate((c: HTMLCanvasElement) => c.toDataURL());
  // Allow a frame after asset loading before comparing a genuinely still scene.
  await page.waitForTimeout(150);
  const still = await snapshot();
  await page.waitForTimeout(400);
  expect(await snapshot()).toBe(still);
  await page.getByRole('button', { name: 'Reduce motion' }).click();
  await expect(page.locator('#scene')).toHaveAttribute('data-motion', 'active');
  await page.waitForTimeout(400);
  expect(await snapshot()).not.toBe(still);
  await page.getByRole('button', { name: 'Reduce motion' }).click();
  await page.waitForTimeout(150);
  const stopped = await snapshot();
  await page.waitForTimeout(400);
  expect(await snapshot()).toBe(stopped);
  expect(failures).toEqual([]);
});
