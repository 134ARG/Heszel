export class HeszelTextInputStyle implements AttributeModifier<TextInputAttribute> {
  private readonly focused: boolean
  private readonly inputHeight: number
  private readonly inputRadius: number

  constructor(focused: boolean, inputHeight: number = 52, inputRadius: number = 14) {
    this.focused = focused
    this.inputHeight = inputHeight
    this.inputRadius = inputRadius
  }

  applyNormalAttribute(input: TextInputAttribute): void {
    input
      .height(this.inputHeight)
      .width('100%')
      .fontColor($r('app.color.text_primary'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.action'))
      .backgroundColor($r('app.color.surface_input'))
      .borderRadius(this.inputRadius)

    // BEGIN OPTIONAL FOCUS OUTLINE
    // Comment out the next line to restore the original borderless input appearance.
    input.outline({
      width: this.focused ? 2 : 0,
      color: $r('app.color.action'),
      radius: this.inputRadius
    })
    // END OPTIONAL FOCUS OUTLINE
  }
}
