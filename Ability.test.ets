import { describe, it, expect } from '@ohos/hypium';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Driver, ON } from '@ohos.UiTest'
import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import WTGJson from './WTG';
import router from '@ohos.router';

const delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
const bundleName = abilityDelegatorRegistry.getArguments().bundleName;

function sleep(time: number) {
  return new Promise<void>((resolve: Function) => setTimeout(resolve, time));
}

class Page {
  name: string
  children: Set<Page>
  actions: Map<Page, Array<Array<string>>>

  constructor(name) {
    this.name = name;
    this.children = new Set();
    this.actions = new Map(); // {children: [(widget, action)...]}
  }

  // 自定义序列化逻辑
  toJSON() {
    return {
      name: this.name,
      children: Array.from(this.children), // 将Set转换为Array
      actions: Array.from(this.actions).map(([key, value]) => ({ key, value })) // 将Map转换为对象数组
    };
  }
}

class ModelTest {
  driver: Driver
  WTG: Map<string, Set<Array<string>>>
  vis: Set<string>
  count: number

  constructor(driver: Driver, WTG: Map<string, Set<Array<string>>>) {
    this.driver = driver;
    this.WTG = WTG;
    this.vis = new Set<string>();
    this.count = 0;
  }

  // async modelTest() {
  //   while (true) {
  //     let curPage = router.getState().path + router.getState().name;
  //     let x = Math.random();
  //     if (x <= 0.2) {
  //       await this.componentScrollToBottom();
  //     } else if (x <= 0.4) {
  //       await this.componentScrollToTop();
  //     }
  //     for (let [widget, action, childPage] of this.WTG.get(curPage)) {
  //       let components = await this.driver.findComponents(ON.type(widget));
  //       // components may be null!!!
  //       let flag = false;
  //       if (components) {
  //         for (let component of components) {
  //           await component.click();
  //           await this.driver.delayMs(2000);
  //           let page = router.getState().path + router.getState().name;
  //           if (page === childPage) {
  //             hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${router.getState().path + router.getState()
  //               .name}`);
  //             flag = true;
  //             continue;
  //           } else if (page === curPage) {
  //
  //           } else {
  //             await this.driver.delayMs(3000);
  //             await this.driver.pressBack();
  //             await this.driver.delayMs(2000);
  //           }
  //         }
  //       }
  //       if (!flag) {
  //         let tabBars = await this.driver.findComponents(ON.type('TabBar'));
  //         for (let tabBar of tabBars) {
  //           let bounds = await tabBar.getBounds();
  //           let left = bounds.left, right = bounds.right, top = bounds.top, bottom = bounds.bottom;
  //           let d = Math.round((right - left) / 4);
  //           for (let i = 1; i <= 4; i++) {
  //             await this.driver.click(i * d - 20, top + 150);
  //             let components = await this.driver.findComponents(ON.type(widget));
  //             if (components) {
  //               for (let component of components) {
  //                 await component.click();
  //                 await this.driver.delayMs(2000);
  //                 let page = router.getState().path + router.getState().name;
  //                 if (page === childPage) {
  //                   hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${router.getState()
  //                     .path + router.getState()
  //                     .name}`);
  //                   flag = true;
  //                   continue;
  //                 } else if (page === curPage) {
  //
  //                 } else {
  //                   await this.driver.delayMs(3000);
  //                   await this.driver.pressBack();
  //                   await this.driver.delayMs(2000);
  //                 }
  //               }
  //             }
  //           }
  //           console.log('driver click over');
  //         }
  //       }
  //     }
  //     for (let i = 0; i < 10; i++) {
  //       if (Math.random() <= 0.6) {
  //         await this.componentClick();
  //       }
  //     }
  //   }
  // }

  async test() {
    let curPage = router.getState().path + router.getState().name;
    if (this.vis.has(curPage)) {
      await this.driver.delayMs(2000);
      await this.driver.pressBack();
      await this.driver.delayMs(2000);
      return;
    }
    this.vis.add(curPage);
    let curLength = router.getLength();
    hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${curPage}`);
    // this.vis.add(curPage);
    hilog.info(0x0000, 'testTag', '%{public}s', `pages vis: ${this.vis.size}}`);
    // let x = Math.random();
    // if (x <= 0.2) {
    //   await this.componentScrollToBottom();
    // } else if (x <= 0.4) {
    //   await this.componentScrollToTop();
    // }
    const children = this.WTG.get(curPage);
    if (!children) {
      return;
    }

      const doAction = async () => {
        for (let [widget, action, childPage] of children) {
          let originPage = router.getState().path + router.getState().name;
          let components = await this.driver.findComponents(ON.type(widget));
          if (components) {
            if (widget === 'ListItem' || widget === 'GridItem') {
              components = [components[0]];
            }
            for (let component of components) {
              let page = router.getState().path + router.getState().name;
              while (page != originPage) {
                await this.test();
                page = router.getState().path + router.getState().name;
              }
              if (action === 'onClick') {
                await component.click();
                this.count++;
                hilog.info(0x0000, 'testTag', '%{public}s', `count: ${this.count}}`);
              }
              await this.driver.delayMs(2000);
              page = router.getState().path + router.getState().name;
              if (page === childPage) {
                hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${router.getState().path + router.getState()
                  .name}`);
                await this.test();
              } else if (page === curPage) {
                await this.driver.delayMs(0);
              } else {
                // await _this.driver.delayMs(2000);
                // await _this.driver.pressBack();
                // await _this.driver.delayMs(2000);
                hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${router.getState().path + router.getState()
                  .name}`);
                await this.test();
              }
            }
          }
        }
      }

      const randomAction = async () => {
        for (let i = 0; i < 10; i++) {
          // let x = Math.random();
          // if (x <= 0.5) {
          //   await this.componentScrollToBottom();
          // } else {
          //   await this.componentScrollToTop();
          // }
          await this.componentClick();
          await this.driver.delayMs(2000);
          let page = router.getState().path + router.getState().name;
          if (!this.vis.has(page) && page !== curPage) {
            await this.test();
          }
        }
      }

      let tabBars = await this.driver.findComponents(ON.type('TabBar'));
      if (tabBars) {
        for (let tabBar of tabBars) {
          let tabBarNum = 4;
          let bounds = await tabBar.getBounds();
          let left = bounds.left, right = bounds.right, top = bounds.top, bottom = bounds.bottom;
          let d = Math.round((right - left) / tabBarNum);
          for (let i = 1; i <= tabBarNum; i++) {
            // let cs = await this.driver.findComponents(ON.enabled(true));
            // while (true) {
            //   await this.driver.click(i * d - 20, top);
            //   let ncs = await this.driver.findComponents(ON.enabled(true));
            //   if (cs.length !== ncs.length) {
            //     break;
            //   }
            // }
            // for (let j = 0; j < 5; j++) {
              await this.driver.click(i * d - 20, top);
              // await this.driver.delayMs(1000);
            // }

            // 594, 2790
            await this.driver.delayMs(2000);
            await doAction();
            if (i == 4) {
              // await randomAction();
            }
          }
        }
      } else {
        await doAction();
        // await randomAction();
      }

    // let enableComponents = await this.driver.findComponents(ON.enabled(true));
    // for (const component of enableComponents) {
    //   let type = await component.getType();
    //   if (widgetSet.has(type)) {
    //     continue;
    //   }
    //   await component.click();
    //   await this.driver.delayMs(2000);
    //   let page = router.getState().path + router.getState().name;
    //   if (page !== curPage) {
    //     await this.test();
    //   }
    // }
    await this.driver.delayMs(2000);
    await this.driver.pressBack();
    await this.driver.delayMs(2000);
  }

  async componentClick() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (enabledComponents && Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      while (true) {
        let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
        let bound = await component.getBounds();
        let type = await component.getType();
        if (type !== 'Image') {
          await component.click();
          this.count++;
          hilog.info(0x0000, 'testTag', '%{public}s', `count: ${this.count}}`);
          hilog.info(0x0000, 'testTag', '%{public}s', `click ${bound.left}, ${bound.top}, ${bound.right}, ${bound.bottom}`);
          break;
        }
      }
    }
  }

  async componentScrollToTop() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (enabledComponents && Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let speed = Math.floor(Math.random() * (15000 - 200) + 200);
      await component.scrollToTop(speed);
      hilog.info(0x0000, 'testTag', '%{public}s', `scrollToTop speed: ${speed}`);
    }
  }

  async componentScrollToBottom() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (enabledComponents && Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let speed = Math.floor(Math.random() * (15000 - 200) + 200);
      await component.scrollToBottom(speed);
      hilog.info(0x0000, 'testTag', '%{public}s', `scrollToBottom speed: ${speed}`);
    }
  }

  async action() {
    // let curPage = router.getState().path + router.getState().name;
    // hilog.info(0x0000, 'testTag', '%{public}s', `currentPage: ${curPage}`);
    // if (this.WTG.get(curPage).size === 0) {
    //   await this.driver.pressBack();
    //   curPage = router.getState().path + router.getState().name;
    // }
    // for (let [widget, action, childPage] of this.WTG.get(curPage)) {
    //   let components = await this.driver.findComponents(ON.type(widget));
    //   for (let component of components) {
    //     await component.click();
    //     let page = router.getState().path + router.getState().name
    //     if (page !== curPage) {
    //       return;
    //     }
    //   }
    // }
    hilog.info(0x0000, 'testTag', '%{public}s', `router.getState(): ${router.getState().path + router.getState()
      .name}`);
    await this.driver.pressBack();
  }
}

class RandomTest {
  driver: Driver
  leftBound: number
  rightBound: number
  topBound: number
  bottomBound: number
  // randomActions = [this.componentClick.bind(this), this.componentDoubleClick.bind(this), this.componentLongClick.bind(this), this.componentScrollToTop.bind(this), this.componentScrollToBottom.bind(this), this.componentDragTo.bind(this), this.componentPinchIn.bind(this), this.componentPinchOut.bind(this), this.componentInputText.bind(this), this.componentClearText.bind(this), this.driverClick.bind(this), this.driverDoubleClick.bind(this), this.driverLongClick.bind(this), this.driverSwipe.bind(this), this.driverDrag.bind(this), this.driverFling.bind(this)];
  randomActions = [this.componentClick.bind(this), this.driverClick.bind(this)];

  constructor(driver: Driver, leftBound: number, rightBound: number, topBound: number, bottomBound: number) {
    this.driver = driver;
    this.leftBound = leftBound;
    this.rightBound = rightBound;
    this.topBound = topBound;
    this.bottomBound = bottomBound;
  }

  async test() {
    let vis = new Set();
    let count = 0;
    while (true) {
      let curPage = router.getState().path + router.getState().name;
      vis.add(curPage);
      await this.action();
      count++;
      await this.driver.delayMs(2000);
      hilog.info(0x0000, 'testTag', '%{public}s', `pages vis: ${vis.size}}`);
      hilog.info(0x0000, 'testTag', '%{public}s', `count: ${count}}`);
    }
  }

  async action() {
    let randomAction: Function = this.randomActions[Math.floor(Math.random() * this.randomActions.length)];
    hilog.info(0x0000, 'testTag', '%{public}s', `randomAction: ${randomAction.name}`);
    await randomAction();
  }

  async componentClick() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let bound = await component.getBounds();
      await component.click();
      hilog.info(0x0000, 'testTag', '%{public}s', `click ${bound.left}, ${bound.top}, ${bound.right}, ${bound.bottom}`);
    }
  }

  async componentDoubleClick() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let bound = await component.getBounds();
      await component.doubleClick();
      hilog.info(0x0000, 'testTag', '%{public}s', `doubleClick ${bound.left}, ${bound.top}, ${bound.right}, ${bound.bottom}`);
    }
  }

  async componentLongClick() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let bound = await component.getBounds();
      await component.longClick();
      hilog.info(0x0000, 'testTag', '%{public}s', `longClick ${bound.left}, ${bound.top}, ${bound.right}, ${bound.bottom}`);
    }
  }

  async componentScrollToTop() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let speed = Math.floor(Math.random() * (15000 - 200) + 200);
      await component.scrollToTop(speed);
      hilog.info(0x0000, 'testTag', '%{public}s', `scrollToTop speed: ${speed}`);
    }
  }

  async componentScrollToBottom() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let speed = Math.floor(Math.random() * (15000 - 200) + 200);
      await component.scrollToBottom(speed);
      hilog.info(0x0000, 'testTag', '%{public}s', `scrollToBottom speed: ${speed}`);
    }
  }

  async componentDragTo() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 1) {
      let i1 = Math.floor(Math.random() * enabledComponents.length);
      let i2 = i1;
      while (i1 == i2) {
        i2 = Math.floor(Math.random() * enabledComponents.length);
      }
      let c1 = enabledComponents[i1];
      let c2 = enabledComponents[i2];
      if (Math.random() < 0.5) {
        await c1.dragTo(c2);
      } else {
        await c2.dragTo(c1);
      }
      hilog.info(0x0000, 'testTag', '%{public}s', 'dragTo');
    }
  }

  async componentPinchIn() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let scale = Math.random() * 10;
      await component.pinchIn(scale);
      hilog.info(0x0000, 'testTag', '%{public}s', `pinchIn: ${scale}`);
    }
  }

  async componentPinchOut() {
    let enabledComponents = await this.driver.findComponents(ON.enabled(true));
    if (Array.isArray(enabledComponents) && enabledComponents.length > 0) {
      let component = enabledComponents[Math.floor(Math.random() * enabledComponents.length)];
      let scale = Math.random() * 10;
      await component.pinchOut(scale);
      hilog.info(0x0000, 'testTag', '%{public}s', `pinchOut: ${scale}`);
    }
  }

  async componentInputText() {

    function getRandomChineseWord() {
      let _rsl = "";
      let _randomUniCode = Math.floor(Math.random() * (40870 - 19968) + 19968).toString(16);
      eval("_rsl=" + '"\\u' + _randomUniCode + '"');
      return _rsl;
    }

    let inputTextComponents = await this.driver.findComponents(ON.type('TextInput'));
    if (Array.isArray(inputTextComponents) && inputTextComponents.length > 0) {
      let component = inputTextComponents[Math.floor(Math.random() * inputTextComponents.length)];
      let inputText;
      if (Math.random() < 0.5) {
        inputText = Math.random().toString(36).slice(-8);
      } else {
        inputText = getRandomChineseWord();
      }
      await component.inputText(inputText);
      hilog.info(0x0000, 'testTag', '%{public}s', `inputText: ${inputText}`);
    }
  }

  async componentClearText() {
    let inputTextComponents = await this.driver.findComponents(ON.type('TextInput'));
    if (Array.isArray(inputTextComponents) && inputTextComponents.length > 0) {
      let component = inputTextComponents[Math.floor(Math.random() * inputTextComponents.length)];
      let text = await component.getText();
      await component.clearText();
      hilog.info(0x0000, 'testTag', '%{public}s', `clearText: ${text}`);
    }
  }

  async driverClick() {
    let x = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    await this.driver.click(x, y);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverClick: ${x}, ${y}`);
  }

  async driverDoubleClick() {
    let x = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    await this.driver.doubleClick(x, y);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverDoubleClick: ${x}, ${y}`);
  }

  async driverLongClick() {
    let x = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    await this.driver.longClick(x, y);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverLongClick: ${x}, ${y}`);
  }

  async driverSwipe() {
    let x1 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let x2 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y1 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let y2 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let speed = Math.floor(Math.random() * (15000 - 200) + 200);
    await this.driver.swipe(x1, y1, x2, y2, speed);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverSwipe: (${x1}, ${y1} -> ${x2}, ${y2})`);
  }

  async driverDrag() {
    let x1 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let x2 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y1 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let y2 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let speed = Math.floor(Math.random() * (15000 - 200) + 200);
    await this.driver.drag(x1, y1, x2, y2, speed);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverDrag: (${x1}, ${y1} -> ${x2}, ${y2})`);
  }

  async driverFling() {
    let x1 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let x2 = Math.floor(Math.random() * (this.rightBound - this.leftBound) + this.leftBound);
    let y1 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let y2 = Math.floor(Math.random() * (this.bottomBound - this.topBound) + this.topBound);
    let stepLen = Math.min(Math.abs(x1 - x2), Math.abs(y1 - y2));
    let speed = Math.floor(Math.random() * (15000 - 200) + 200);
    await this.driver.fling({ x: x1, y: y1 }, { x: x2, y: y2 }, stepLen, speed);
    hilog.info(0x0000, 'testTag', '%{public}s', `driverDrag: (${x1}, ${y1} -> ${x2}, ${y2})`);
  }
}


export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    it('testUiExample', 0, async (done: Function) => {
      console.info("uitest: TestUiExample begin");
      // start tested ability
      await delegator.executeShellCommand(`aa start -d 0 -a EntryAbility -b ${bundleName}`)
        .then((result: abilityDelegatorRegistry.ShellCmdResult) => {
          console.info('Uitest, start ability finished:' + result)
        })
        .catch((err) => {
          console.info('Uitest, start ability failed: ' + err)
        })

      // const want: Want = {
      //   bundleName: bundleName,
      //   abilityName: 'EntryAbility'
      // };
      // await delegator.startAbility(want);
      await sleep(3000);
      // Check the top display ability.
      await delegator.getCurrentTopAbility().then((Ability: UIAbility) => {
        console.info("get top ability");
        expect(Ability.context.abilityInfo.name).assertEqual('EntryAbility');
      })

      let obj: { [key: string]: Array<[string, string, string]> } = JSON.parse(WTGJson);
      // const WTG: Map<string, Set<[string, string, string]>> = new Map(Object.entries(obj)
      //   .map(([key, value]) => [key, new Set(value)]));
      const project = 'HarmoneyOpenEye';
      const prefix = `D:/project/CS490/${project}/entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/`;
      const WTG = new Map();
      for (let [pageName, actions] of Object.entries(obj)) {
        // pageName = pageName.substring(prefix.length, pageName.lastIndexOf('.js'));
        // console.log(pageName, actions);
        WTG.set(pageName, new Set());
        for (const action of actions) {
          // action[2] = action[2].substring(prefix.length, action[2].lastIndexOf('.js'));
          WTG.get(pageName).add(action);
        }
      }

      // UI test code
      // Initialize the driver.
      let driver = Driver.create();
      await driver.delayMs(1000);
      const root = await driver.findComponent(ON.type('root'));
      const bound = await root.getBounds();
      // const randomTest: RandomTest = new RandomTest(driver, bound.left, bound.right, bound.top, bound.bottom);
      const modelTest: ModelTest = new ModelTest(driver, WTG);
      // let tabBars = await driver.findComponents(ON.type('TabBar'));
      // await randomTest.test();
      // let tabBar = await driver.findComponent(ON.type('TabBar'));
      // let b = await tabBar.getBounds();
      // let l = b.left, r = b.right, t = b.top, bo = b.bottom;
      // let x = Math.round((r - l) / 4), y = t;
      // //307,2724
      // 307, 2640
      // await driver.click(307*2,2700);
      // await driver.click(x - 20, y);
      // await driver.delayMs(2000);
      // await driver.click(2 * x - 20, y);
      // await driver.delayMs(2000);
      // await driver.click(3 * x - 20, y);
      // await driver.delayMs(2000);
      // await driver.click(4 * x - 20, y);
      // await driver.delayMs(2000);
      // await randomTest.test();
      // await modelTest.test();
      // await driver.click(594, 2790);
      // await driver.delayMs(2000);
      // let components = await driver.findComponents(ON.type('Image'));
      // for (let component of components) {
      //   await component.click();
      //   await driver.delayMs(2000);
      //   let id = await component.getId();
      //   console.log(id);
      // }
      // await randomTest.test();
      await modelTest.test();
      // let component = await driver.waitForComponent(ON.type('Button'), 5000);
      // await component.click();
      // await driver.delayMs(2000);
      // await driver.pressBack();
      // await driver.delayMs(2000);
      // await driver.delayMs(100000);
      done();
    })
  })
}